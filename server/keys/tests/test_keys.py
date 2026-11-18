from accounts.models import AuditEvent, Notification, verify_audit_chain
from keys.models import UserKey


def test_first_key_is_active_and_later_keys_wait_for_the_manager(api, make_user, manager, device):
    user = make_user("a@corp.test")
    phone = device(user, "phone")
    laptop = device(user, "laptop")
    mine = {k["device_name"]: k["status"] for k in phone.call("get", "/keys/mine").data}
    assert mine == {"phone": "active", "laptop": "pending"}
    boss = device(manager)
    assert [k["device_name"] for k in boss.call("get", "/keys/pending").data] == ["laptop"]
    assert phone.call("get", "/keys/pending").status_code == 403
    assert phone.call("post", f"/keys/{laptop.key_id}/approve").status_code == 403
    assert boss.call("post", f"/keys/{laptop.key_id}/approve").data["status"] == "active"
    assert AuditEvent.objects.filter(action="key_approved").exists()
    assert Notification.objects.filter(user=user, kind="key_change").count() >= 2  # owner is alerted
    assert verify_audit_chain() is None


def test_key_upload_validates_keys_and_fingerprint(api, make_user, device):
    user = make_user("a@corp.test")
    d = device(user, register=False)
    bad_fp = d.call("post", "/keys", {"sign_pub": d.sign_pub, "enc_pub": d.enc_pub, "fingerprint": "nope"})
    assert bad_fp.status_code == 422
    off_curve = {**d.sign_pub, "y": d.sign_pub["x"]}
    assert d.call("post", "/keys", {"sign_pub": off_curve, "enc_pub": d.enc_pub}).status_code == 422
    with_private = {**d.sign_pub, "d": "secret"}
    d.call("post", "/keys", {"sign_pub": with_private, "enc_pub": d.enc_pub})
    assert "d" not in UserKey.objects.get().sign_pub  # private members are never stored
    assert d.call("post", "/keys", {"sign_pub": d.sign_pub, "enc_pub": d.enc_pub}).status_code == 409


def test_directory_lists_only_active_keys_of_active_users(api, make_user, device):
    a, b = make_user("a@corp.test"), make_user("b@corp.test")
    da, db_ = device(a), device(b)
    device(b, "second")  # pending
    users = {u["email"]: u for u in da.call("get", "/keys/directory").data}
    assert [k["device_name"] for k in users["b@corp.test"]["keys"]] == ["phone"]
    b.is_active = False
    b.save()
    assert "b@corp.test" not in {u["email"] for u in da.call("get", "/keys/directory").data}
    assert db_.key_id


def test_retire_by_owner_or_manager_only(api, make_user, manager, device):
    a, b = make_user("a@corp.test"), make_user("b@corp.test")
    da, db_, boss = device(a), device(b), device(manager)
    assert da.call("post", f"/keys/{db_.key_id}/retire").status_code == 403
    assert da.call("post", f"/keys/{da.key_id}/retire").data["status"] == "retired"
    assert boss.call("post", f"/keys/{db_.key_id}/retire").data["status"] == "retired"
    assert db_.call("post", f"/keys/{db_.key_id}/retire").status_code == 409


def test_transfer_events_are_audited(api, make_user, device):
    d = device(make_user("a@corp.test"))
    assert d.call("post", f"/keys/{d.key_id}/transfer-event", {"kind": "export"}).status_code == 200
    assert d.call("post", f"/keys/{d.key_id}/transfer-event", {"kind": "steal"}).status_code == 422
    assert AuditEvent.objects.filter(action="key_export").exists()


def test_company_key_versions_and_wraps(api, make_user, manager, device):
    user = make_user("a@corp.test")
    du, boss = device(user), device(manager)
    wraps = [{"key_id": boss.key_id, "wrap": {"ct": "x"}}]
    assert du.call("post", "/keys/company", {"version": 1, "wraps": wraps}).status_code == 403
    assert boss.call("post", "/keys/company", {"version": 2, "wraps": wraps}).status_code == 409
    assert boss.call("post", "/keys/company", {"version": 1, "wraps": wraps}).status_code == 200
    assert [k["id"] for k in boss.call("get", "/keys/company/missing").data] == [du.key_id]
    boss.call("post", "/keys/company", {"version": 1, "wraps": [{"key_id": du.key_id, "wrap": {"ct": "y"}}]})
    assert du.call("get", "/keys/company/mine").data[0]["version"] == 1
    assert du.call("get", "/keys/company/status").data == {"version": 1, "needs_rotation": False}
