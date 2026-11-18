import pytest
from django.db import connection, transaction

from accounts.models import AuditEvent, Notification, verify_audit_chain
from letters.models import LetterEvent, Signature


def ids(resp):
    return {x["id"] for x in resp.data}


def test_three_signers_publish_a_public_letter_and_viewers_only_then_see_it(world):
    letter = world.create()
    lid = letter["id"]
    assert letter["status"] == "in_signing"
    assert lid not in ids(world.dev(world.outsider).call("get", "/letters"))  # after_sign: not shown yet
    assert world.dev(world.outsider).call("get", f"/letters/{lid}").status_code == 404
    for s in world.signers[:2]:
        assert world.sign(s, lid).status_code == 200
    assert world.alice_d.call("get", f"/letters/{lid}").data["status"] == "in_signing"
    assert world.sign(world.signers[2], lid).data["status"] == "published"
    assert lid in ids(world.dev(world.outsider).call("get", "/letters"))  # public: everyone with letter.see
    assert [s["decision"] for s in world.alice_d.call("get", f"/letters/{lid}").data["signatures"]] == ["approved"] * 3
    assert Notification.objects.filter(kind="letter_published", user=world.outsider).exists()
    assert verify_audit_chain() is None


def test_private_letter_is_limited_to_participants_and_listed_viewers(world):
    lid = world.create(visibility="private", viewers=[world.viewer], mode="now")["id"]
    assert lid in ids(world.dev(world.viewer).call("get", "/letters"))
    assert world.dev(world.outsider).call("get", f"/letters/{lid}").status_code == 404
    assert world.dev(world.signers[0]).call("get", f"/letters/{lid}").status_code == 200  # signers always see


def test_publish_now_shows_viewers_at_send_but_status_waits_for_signatures(world):
    letter = world.create(mode="now")
    assert world.dev(world.outsider).call("get", f"/letters/{letter['id']}").data["status"] == "in_signing"


def test_serial_order_blocks_out_of_turn_signing(world):
    lid = world.create(order="serial")["id"]
    assert world.sign(world.signers[1], lid).status_code == 409
    assert world.sign(world.signers[0], lid).status_code == 200
    assert Notification.objects.filter(user=world.signers[1], title__startswith="Your turn").exists()
    assert world.sign(world.signers[1], lid).status_code == 200


def test_reject_is_final_and_a_chained_letter_shows_under_its_parent(world):
    lid = world.create()["id"]
    assert world.sign(world.signers[0], lid, "rejected", "no budget").data["status"] == "rejected"
    assert world.sign(world.signers[1], lid).status_code == 409
    child = world.create(parent=lid)
    detail = world.alice_d.call("get", f"/letters/{lid}").data
    assert [c["id"] for c in detail["children"]] == [child["id"]]
    assert world.alice_d.call("get", f"/letters/{child['id']}").data["parent_id"] == lid


def test_sent_letter_is_immutable_and_creator_can_cancel_while_in_signing(world):
    lid = world.create()["id"]
    assert world.alice_d.call("put", f"/letters/{lid}", world.body()).status_code == 409
    assert world.alice_d.call("post", f"/letters/{lid}/cancel").data["status"] == "cancelled"
    assert world.alice_d.call("post", f"/letters/{lid}/cancel").status_code == 409


def test_permissions_are_enforced(world, make_user, dev):
    no_perm = dev(make_user("plain@corp.test"))
    assert no_perm.call("post", "/letters", world.body()).status_code == 403
    cannot_sign = make_user("nosign@corp.test")
    world.d[cannot_sign.email] = dev(cannot_sign)
    data = world.body(signers=[cannot_sign])
    assert world.alice_d.call("post", "/letters", data).status_code == 422


def test_manager_unlist_hides_from_users_but_keeps_participants_history(world):
    lid = world.create()["id"]
    for s in world.signers:
        world.sign(s, lid)
    assert world.dev(world.signers[0]).call("post", f"/letters/{lid}/unlist", {}).status_code == 403
    assert world.boss.call("post", f"/letters/{lid}/unlist", {}).data["unlisted"] is True
    assert lid not in ids(world.dev(world.outsider).call("get", "/letters"))
    assert lid in ids(world.dev(world.signers[0]).call("get", "/letters"))
    assert lid in ids(world.alice_d.call("get", "/letters"))
    assert world.boss.call("post", f"/letters/{lid}/unlist", {"unlisted": False}).data["unlisted"] is False
    draft = world.create(send=False)["id"]
    assert world.boss.call("post", f"/letters/{draft}/unlist", {}).status_code == 409  # only published letters


def test_manager_sees_title_and_participants_but_never_the_body(world):
    world.create()
    rows = world.boss.call("get", "/letters/admin").data
    assert rows[0]["title"] == "Budget 2027" and len(rows[0]["participants"]) == 3
    assert "body" not in rows[0] and "signatures" not in rows[0]
    assert world.boss.call("get", f"/letters/{rows[0]['id']}").status_code == 404  # no reading either
    assert world.alice_d.call("get", "/letters/admin").status_code == 403


def test_history_is_identical_for_every_session_of_a_user(world, api):
    world.create()
    second_session = api.login(world.alice.email, device="laptop")["access"]
    first = world.alice_d.call("get", "/letters").data
    assert api.call("get", "/letters", token=second_session).data == first


def test_nothing_can_be_deleted_or_rewritten_in_the_database(world):
    lid = world.create()["id"]
    world.sign(world.signers[0], lid)
    def refused(action):
        with pytest.raises(Exception, match="not allowed"), transaction.atomic():
            action()

    def raw_delete(table):
        def run():
            with connection.cursor() as cur:
                cur.execute(f"DELETE FROM {table}")
        return run

    for table in ("letters_letter", "accounts_user", "letters_signature", "accounts_session"):
        refused(raw_delete(table))
    refused(lambda: Signature.objects.update(decision="rejected"))


def test_audit_chain_detects_tampering(world):
    world.create()
    assert verify_audit_chain() is None
    victim = AuditEvent.objects.exclude(hash="").order_by("id")[1]
    with connection.cursor() as cur:  # the UPDATE trigger would stop this, so drop it to simulate a DBA attack
        cur.execute("DROP TRIGGER no_update_accounts_auditevent")
        cur.execute("UPDATE accounts_auditevent SET target='forged' WHERE id=%s", [victim.id])
    assert verify_audit_chain() == victim.id


def test_event_catch_up_returns_only_visible_events_after_the_cursor(world):
    lid = world.create()["id"]
    world.sign(world.signers[0], lid)
    events = world.alice_d.call("get", "/letters/events?after=0").data
    assert [e["kind"] for e in events] == ["sent", "signed"]
    cursor = events[0]["event_id"]
    assert [e["kind"] for e in world.alice_d.call("get", f"/letters/events?after={cursor}").data] == ["signed"]
    assert world.dev(world.outsider).call("get", "/letters/events?after=0").data == []
    assert LetterEvent.objects.count() == 2


def test_attachments_are_limited_to_pdf_and_images_and_size(world, settings, tmp_path):
    from django.core.files.uploadedfile import SimpleUploadedFile

    settings.MEDIA_ROOT = tmp_path
    settings.MAX_ATTACHMENT_BYTES = 10
    lid = world.create(send=False)["id"]
    d = world.alice_d

    def upload(content_type, blob):
        return d.api.client.post(f"/api/letters/{lid}/attachments", {
            "content_type": content_type, "file": SimpleUploadedFile("x", blob)},
            HTTP_AUTHORIZATION=f"Bearer {d.token}")

    assert upload("text/html", b"abc").status_code == 422
    assert upload("application/pdf", b"x" * 11).status_code == 413
    ok = upload("application/pdf", b"%PDF-plain")
    assert ok.status_code == 201 and ok.json()["size"] == 10 and "iv" not in ok.json()
    aid = ok.json()["id"]
    got = d.api.client.get(f"/api/letters/{lid}/attachments/{aid}", HTTP_AUTHORIZATION=f"Bearer {d.token}")
    assert got.content == b"%PDF-plain" and got["Content-Type"] == "application/pdf"
    assert d.api.client.get(f"/api/letters/{lid}/attachments/{aid}",
                            HTTP_AUTHORIZATION=f"Bearer {world.dev(world.outsider).token}").status_code == 404


def test_certificate_reverifies_every_signature(world):
    lid = world.create()["id"]
    for s in world.signers:
        world.sign(s, lid)
    cert = world.alice_d.call("get", f"/letters/{lid}/certificate").data
    assert cert["all_verified"] and len(cert["signatures"]) == 3
    assert world.dev(world.viewer).call("get", f"/letters/{lid}/certificate").data["all_verified"]  # public
    assert Signature.objects.count() == 3
    assert cert["signatures"][0]["device"] == "phone" and cert["signatures"][0]["method"] == "pin"


def test_superuser_admin_shows_no_letter_titles_and_audit_csv_exports(world, client):
    from django.test import Client

    from accounts.models import User

    lid = world.create()["id"]
    for s in world.signers:
        world.sign(s, lid)
    world.boss.call("post", f"/letters/{lid}/unlist", {})
    assert "Budget" not in " ".join(str(e.data) + e.target for e in AuditEvent.objects.all())
    root = User.objects.create_superuser("root@corp.test", "x" * 20)
    admin = Client()
    admin.force_login(root)
    resp = admin.post("/admin/accounts/auditevent/", {"action": "export_audit_csv",
                                                    "_selected_action": [AuditEvent.objects.first().pk]})
    assert resp.status_code == 200 and resp["Content-Type"] == "text/csv"
    assert admin.get("/admin/letters/letter/").status_code == 404  # letters are not in the superuser admin
    assert admin.get("/admin/letters/signature/").status_code == 404
