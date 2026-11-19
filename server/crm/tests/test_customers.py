import json

import pytest
from django.db.utils import DatabaseError

from accounts.models import AuditEvent, Notification
from crm.models import CallReport, Customer, CustomerEvent
from workspace.models import ChangeHistory, Event


def test_create_returns_out_with_defaults_and_encrypts_free_text(team, file):
    assert file["name"] == "ACME" and file["status"] == "active" and file["email"] == "info@acme.test"
    assert file["my_role"] == "manager" and file["owner"]["id"] == team.ann.id
    assert file["address"] == {"text": "Secret street 1"} and file["notes"] == {"text": "Secret notes"}
    assert {m["user"]["id"]: m["role"] for m in file["members"]} == {
        team.ann.id: "manager", team.bob.id: "member", team.vic.id: "viewer"}
    assert file["can"]["edit"] and file["can"]["members"]
    row = Customer.objects.get(pk=file["id"])
    assert row.address["v"] == 3 and "Secret street" not in json.dumps(row.address)
    assert "Secret notes" not in json.dumps(row.notes)
    assert row.subject.module == "crm" and row.subject.kind == "customer"


def test_create_needs_the_permission(team, make_user, login):
    plain = login(make_user("plain@corp.test"))
    assert plain.call("post", "/customers", {"name": "X"}).status_code == 403


def test_limit_counts_every_status(team, settings):
    settings.CUSTOMER_LIMIT = 2
    assert team.ann_d.call("post", "/customers", {"name": "a"}).status_code == 201
    assert team.ann_d.call("post", "/customers", {"name": "b", "status": "archived"}).status_code == 201
    resp = team.bob_d.call("post", "/customers", {"name": "c"})
    assert resp.status_code == 409 and resp.data["detail"] == "Customer limit reached"


def test_permission_matrix(team, file):
    cid = file["id"]
    assert team.out_d.call("get", f"/customers/{cid}").status_code == 404
    assert team.boss.call("get", f"/customers/{cid}").status_code == 404  # the company manager gets nothing
    assert team.out_d.call("get", f"/customers/{cid}/events").status_code == 404
    assert team.vic_d.call("get", f"/customers/{cid}").status_code == 200
    assert team.vic_d.call("patch", f"/customers/{cid}", {"name": "x"}).status_code == 403
    assert team.bob_d.call("patch", f"/customers/{cid}", {"name": "x"}).status_code == 403
    assert team.bob_d.call("put", f"/customers/{cid}/members", []).status_code == 403
    assert team.bob_d.call("post", f"/customers/{cid}/events", {"summary": "hi"}).status_code == 201
    assert team.vic_d.call("post", f"/customers/{cid}/events", {"summary": "hi"}).status_code == 403
    assert team.vic_d.call("post", f"/customers/{cid}/calls", {"direction": "in"}).status_code == 403
    assert team.vic_d.call("post", f"/subjects/{file['subject_id']}/comments",
                           {"body": {"text": "ok"}}).status_code == 201
    assert team.out_d.call("get", f"/subjects/{file['subject_id']}/comments").status_code == 404


def test_list_filters_and_visibility(team, file):
    team.ann_d.call("post", "/customers", {"name": "Zed Person", "mobile": "0912", "status": "inactive"})
    assert [c["name"] for c in team.ann_d.call("get", "/customers").data] == ["ACME", "Zed Person"]
    assert [c["name"] for c in team.bob_d.call("get", "/customers").data] == ["ACME"]
    assert team.out_d.call("get", "/customers").data == []
    for q in ("acme", "021111", "1010", "info@acme", "0912"):
        assert team.ann_d.call("get", f"/customers?q={q}").data, q
    assert [c["name"] for c in team.ann_d.call("get", "/customers?status=inactive").data] == ["Zed Person"]
    assert [c["name"] for c in team.ann_d.call("get", "/customers?kind=company").data] == ["ACME"]
    assert team.bob_d.call("get", "/customers?mine=true").data == []
    assert len(team.ann_d.call("get", "/customers?limit=1&offset=1").data) == 1


def test_label_filter(team, file):
    label = team.boss.call("post", "/labels", {"name": "VIP", "color": 1, "scope": "org"}).data
    sid = file["subject_id"]
    assert team.ann_d.call("put", f"/subjects/{sid}/labels", {"label_ids": [label["id"]]}).status_code == 200
    assert team.bob_d.call("put", f"/subjects/{sid}/labels", {"label_ids": []}).status_code == 200
    assert team.vic_d.call("put", f"/subjects/{sid}/labels", {"label_ids": [label["id"]]}).status_code == 403
    team.ann_d.call("put", f"/subjects/{sid}/labels", {"label_ids": [label["id"]]})
    assert [c["name"] for c in team.ann_d.call("get", f"/customers?label={label['id']}").data] == ["ACME"]


def test_patch_writes_history_and_hides_encrypted_values(team, file):
    cid = file["id"]
    resp = team.ann_d.call("patch", f"/customers/{cid}", {"name": "ACME Ltd", "notes": {"text": "new secret"},
                                                          "status": "inactive", "phone": None})
    assert resp.status_code == 200 and resp.data["name"] == "ACME Ltd" and resp.data["phone"] == ""
    rows = {h.field: h for h in ChangeHistory.objects.filter(subject_id=file["subject_id"])}
    assert rows["name"].old == "ACME" and rows["name"].new == "ACME Ltd"
    assert rows["notes"].new == {"changed": True} and rows["notes"].old is None
    assert "new secret" not in json.dumps([h.new for h in rows.values()])
    hist = team.bob_d.call("get", f"/customers/{cid}/history").data
    assert {"name", "notes", "status", "phone"} <= {h["field"] for h in hist}
    assert team.out_d.call("get", f"/customers/{cid}/history").status_code == 404
    assert team.ann_d.call("patch", f"/customers/{cid}", {"name": None}).status_code == 422
    assert not any("ACME" in json.dumps(e.data) for e in AuditEvent.objects.all())


def test_members_replace_and_notify(team, file, make_user, django_capture_on_commit_callbacks):
    cid = file["id"]
    new = make_user("new@corp.test")
    body = [{"user_id": team.bob.id, "role": "manager"}, {"user_id": new.id, "role": "viewer"},
            {"user_id": team.ann.id, "role": "manager"}]
    with django_capture_on_commit_callbacks(execute=True):
        resp = team.ann_d.call("put", f"/customers/{cid}/members", body)
    assert resp.status_code == 200
    assert {m["user"]["id"]: m["role"] for m in resp.data["members"]} == {
        team.ann.id: "manager", team.bob.id: "manager", new.id: "viewer"}
    assert Notification.objects.filter(user=new, kind="customer.member_added").exists()
    assert Event.objects.filter(module="crm", kind="customer.member.added").exists()
    assert team.vic_d.call("get", f"/customers/{cid}").status_code == 404  # removed
    assert team.ann_d.call("put", f"/customers/{cid}/members", [{"user_id": team.bob.id, "role": "manager"}]
                           ).status_code == 422  # owner missing
    assert team.ann_d.call("put", f"/customers/{cid}/members", [{"user_id": team.ann.id, "role": "member"}]
                           ).status_code == 422  # owner demoted
    assert team.ann_d.call("put", f"/customers/{cid}/members", [{"user_id": 9999, "role": "member"},
                                                                {"user_id": team.ann.id, "role": "manager"}]
                           ).status_code == 422


def test_created_event_goes_to_members(team, file):
    kinds = set(Event.objects.filter(module="crm").values_list("kind", flat=True))
    assert "customer.created" in kinds


def test_timeline_notes_and_manual_kinds(team, file):
    cid = file["id"]
    resp = team.bob_d.call("post", f"/customers/{cid}/events", {"kind": "lead", "summary": "Wants a quote"})
    assert resp.status_code == 201 and resp.data["kind"] == "lead" and resp.data["by"]["id"] == team.bob.id
    assert team.bob_d.call("post", f"/customers/{cid}/events", {"kind": "system", "summary": "x"}).status_code == 422
    row = CustomerEvent.objects.get(pk=resp.data["id"])
    assert "quote" not in json.dumps(row.summary)
    listed = team.vic_d.call("get", f"/customers/{cid}/events").data
    assert listed[0]["summary"] == "Wants a quote"
    assert team.vic_d.call("get", f"/customers/{cid}/events?kind=note").data == []
    with pytest.raises(DatabaseError):
        CustomerEvent.objects.filter(pk=row.pk).update(kind="note")
    with pytest.raises(DatabaseError):
        row.delete()


def test_calls_log_to_timeline_and_become_tasks(team, file):
    cid = file["id"]
    resp = team.bob_d.call("post", f"/customers/{cid}/calls", {
        "direction": "in", "contact_name": "Mr Rad", "summary": "Asked for a discount", "duration_s": 90})
    assert resp.status_code == 201 and resp.data["summary"] == "Asked for a discount"
    call = CallReport.objects.get(pk=resp.data["id"])
    assert "discount" not in json.dumps(call.summary)
    assert team.vic_d.call("get", f"/customers/{cid}/calls").data[0]["contact_name"] == "Mr Rad"
    assert team.bob_d.call("get", f"/customers/{cid}/events?kind=call").data
    made = team.bob_d.call("post", f"/customers/{cid}/calls/{call.id}/to-task",
                           {"owner_ids": [team.ann.id], "due_at": "2030-01-01T08:00:00Z"})
    assert made.status_code == 201, made.content
    assert made.data["customer_id"] == cid and made.data["customer_name"] == "ACME"
    assert made.data["title"] == "Follow up: Mr Rad" and made.data["owner_ids"] == [team.ann.id]
    assert team.bob_d.call("get", f"/customers/{cid}/events?kind=task").data
    assert team.vic_d.call("post", f"/customers/{cid}/calls/{call.id}/to-task", {}).status_code == 403
    assert team.bob_d.call("post", f"/customers/{cid}/calls/99999/to-task", {}).status_code == 404
    assert team.bob_d.call("post", f"/customers/{cid}/calls/{call.id}/to-task", {"title": "Call back"}
                           ).data["title"] == "Call back"


def test_call_to_task_needs_task_create(team, file, make_user, login):
    only_crm = make_user("crmonly@corp.test", grants=("customer.create",))
    d = login(only_crm)
    cid = d.call("post", "/customers", {"name": "Mine"}).data["id"]
    call = d.call("post", f"/customers/{cid}/calls", {"direction": "out"}).data
    assert d.call("post", f"/customers/{cid}/calls/{call['id']}/to-task", {}).status_code == 403


def test_module_off_hides_everything(team, file, brand_dir):
    brand_dir(modules=["letters", "tasks"])
    assert team.ann_d.call("get", "/customers").status_code == 404
    assert team.ann_d.call("get", f"/customers/{file['id']}").status_code == 404
    brand_dir(modules=["crm"])
    assert team.ann_d.call("get", "/customers").status_code == 200
    assert "crm" in {m["code"] for m in team.ann_d.call("get", "/me/modules").data["modules"]}


def test_permission_seeding(db):
    from accounts.models import Permission, User

    assert Permission.objects.filter(code="customer.import").exists()
    assert not User.objects.filter(grants__code="customer.import").exists()


def test_brand_json_lists_crm():
    import json as j
    from pathlib import Path

    path = Path(__file__).resolve().parents[3] / "brands" / "demo" / "brand.json"
    assert "crm" in j.loads(path.read_text(encoding="utf-8"))["modules"]
