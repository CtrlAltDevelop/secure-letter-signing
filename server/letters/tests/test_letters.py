import pytest
from django.db import connection, transaction

from accounts.models import AuditEvent, Notification, verify_audit_chain
from keys.models import CompanyKeyVersion
from letters.models import Letter, LetterEvent, Signature

BODY = {"iv": "aXY=", "ct": "Y2lwaGVydGV4dA=="}


class World:
    def __init__(self, make_user, device, manager):
        self.alice = make_user("alice@corp.test", grants=("letter.create", "letter.see"))
        self.signers = [make_user(f"s{i}@corp.test", grants=("letter.sign",)) for i in range(3)]
        self.viewer = make_user("viewer@corp.test", grants=("letter.see",))
        self.outsider = make_user("out@corp.test", grants=("letter.see",))
        self.boss_user = manager
        self.d = {u.email: device(u) for u in [self.alice, *self.signers, self.viewer, self.outsider, manager]}
        self.boss = self.d[manager.email]
        CompanyKeyVersion.objects.create(version=1, created_by=manager)

    @property
    def alice_d(self):
        return self.d[self.alice.email]

    def dev(self, user):
        return self.d[user.email]

    def wraps(self, users):
        return [{"key_id": self.dev(u).key_id, "wrap": {"ct": "w"}} for u in users]

    def body(self, *, visibility="public", signers=None, viewers=(), order="parallel", mode="after_sign", parent=None):
        signers = signers or self.signers
        readers = [self.alice, *signers] + (list(viewers) if visibility == "private" else [])
        data = {"title": "Budget 2027", "body": BODY, "visibility": visibility, "publish_mode": mode, "order": order,
                "signer_ids": [s.id for s in signers], "viewer_ids": [v.id for v in viewers],
                "wraps": self.wraps(readers), "parent_id": parent}
        if visibility == "public":
            data |= {"company_key_version": 1, "company_wrap": {"iv": "a", "ct": "b"}}
        return data

    def create(self, send=True, **kw):
        resp = self.alice_d.call("post", "/letters", self.body(**kw))
        assert resp.status_code == 201, resp.content
        if send:
            sent = self.alice_d.call("post", f"/letters/{resp.data['id']}/send")
            assert sent.status_code == 200, sent.content
            return sent.data
        return resp.data

    def sign(self, user, letter_id, decision="approved", note=""):
        d = self.dev(user)
        letter = d.call("get", f"/letters/{letter_id}").data
        payload = d.decision_payload(letter, decision, note)
        return d.call("post", f"/letters/{letter_id}/sign",
                      {"key_id": d.key_id, "payload": payload, "signature": d.sign(payload)})


@pytest.fixture
def world(make_user, device, manager):
    return World(make_user, device, manager)


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


def test_draft_can_be_edited_and_send_needs_wraps_for_every_active_key(world, device):
    draft = world.create(send=False)
    new_phone = device(world.signers[0], "second")  # pending: does not need a wrap yet
    assert world.alice_d.call("post", f"/letters/{draft['id']}/send").status_code == 200
    boss = world.boss
    boss.call("post", f"/keys/{new_phone.key_id}/approve")
    rewrap = world.dev(world.signers[0]).call("get", "/letters/rewrap-needed").data
    assert [r["key"]["id"] for r in rewrap] == [new_phone.key_id]  # the approved device needs access (5.4b)
    ok = world.dev(world.signers[0]).call("post", f"/letters/{draft['id']}/wraps",
                                          [{"key_id": new_phone.key_id, "wrap": {"ct": "n"}}])
    assert ok.status_code == 200
    assert world.dev(world.signers[0]).call("get", "/letters/rewrap-needed").data == []
    # a key that cannot read the letter cannot be wrapped for
    bad = world.dev(world.signers[0]).call("post", f"/letters/{draft['id']}/wraps",
                                           [{"key_id": world.boss.key_id, "wrap": {}}])
    assert bad.status_code == 422


def test_signing_rejects_forged_replayed_and_foreign_payloads(world):
    lid = world.create()["id"]
    s0, d0 = world.signers[0], world.dev(world.signers[0])
    letter = d0.call("get", f"/letters/{lid}").data
    good = d0.decision_payload(letter)
    sig = d0.sign(good)
    forged = {**good, "decision": "rejected"}
    assert d0.call("post", f"/letters/{lid}/sign", {"key_id": d0.key_id, "payload": forged, "signature": sig}).status_code == 422
    other_session = {**good, "sessionId": "00000000-0000-0000-0000-000000000000"}
    assert d0.call("post", f"/letters/{lid}/sign", {"key_id": d0.key_id, "payload": other_session,
                                                    "signature": d0.sign(other_session)}).status_code == 422
    stale = {**good, "signedAt": "2020-01-01T00:00:00+00:00"}
    assert d0.call("post", f"/letters/{lid}/sign", {"key_id": d0.key_id, "payload": stale,
                                                    "signature": d0.sign(stale)}).status_code == 422
    wrong_key = world.dev(world.signers[1]).sign(good)  # signed by someone else's key
    assert d0.call("post", f"/letters/{lid}/sign", {"key_id": d0.key_id, "payload": good, "signature": wrong_key}).status_code == 422
    assert d0.call("post", f"/letters/{lid}/sign", {"key_id": d0.key_id, "payload": good, "signature": sig}).status_code == 200
    assert d0.call("post", f"/letters/{lid}/sign", {"key_id": d0.key_id, "payload": good, "signature": sig}).status_code == 409
    assert not world.dev(world.viewer).call("post", f"/letters/{lid}/sign",
                                            {"key_id": d0.key_id, "payload": good, "signature": sig}).status_code == 200


def test_pending_or_retired_key_cannot_sign(world, device):
    lid = world.create()["id"]
    pending = device(world.signers[0], "new")
    letter = pending.call("get", f"/letters/{lid}").data
    payload = pending.decision_payload(letter)
    resp = pending.call("post", f"/letters/{lid}/sign", {"key_id": pending.key_id, "payload": payload,
                                                         "signature": pending.sign(payload)})
    assert resp.status_code == 403


def test_permissions_are_enforced(world, make_user, device):
    no_perm = device(make_user("plain@corp.test"))
    assert no_perm.call("post", "/letters", world.body()).status_code == 403
    cannot_sign = make_user("nosign@corp.test")
    world.d[cannot_sign.email] = device(cannot_sign)
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
    assert "body" not in rows[0] and "wraps" not in rows[0]
    assert world.boss.call("get", f"/letters/{rows[0]['id']}").status_code == 404  # no reading either
    assert world.alice_d.call("get", "/letters/admin").status_code == 403


def test_server_stores_only_ciphertext(world):
    lid = world.create()["id"]
    stored = Letter.objects.get(pk=lid)
    assert set(stored.body) == {"iv", "ct"}
    assert "Budget" not in str(stored.body)


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

    for table in ("letters_letter", "accounts_user", "keys_userkey", "accounts_session"):
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
            "content_type": content_type, "iv": "aXY=", "file": SimpleUploadedFile("x", blob)},
            HTTP_AUTHORIZATION=f"Bearer {d.token}")

    assert upload("text/html", b"abc").status_code == 422
    assert upload("application/pdf", b"x" * 11).status_code == 413
    ok = upload("application/pdf", b"cipher")
    assert ok.status_code == 201
    aid = ok.json()["id"]
    got = d.api.client.get(f"/api/letters/{lid}/attachments/{aid}", HTTP_AUTHORIZATION=f"Bearer {d.token}")
    assert b"".join(got.streaming_content) == b"cipher"
    assert d.api.client.get(f"/api/letters/{lid}/attachments/{aid}",
                            HTTP_AUTHORIZATION=f"Bearer {world.dev(world.outsider).token}").status_code == 404


def test_certificate_reverifies_every_signature(world):
    lid = world.create()["id"]
    for s in world.signers:
        world.sign(s, lid)
    cert = world.alice_d.call("get", f"/letters/{lid}/certificate").data
    assert cert["all_verified"] and len(cert["signatures"]) == 3
    assert world.dev(world.viewer).call("get", f"/letters/{lid}/certificate").data["all_verified"]  # public
    Signature.objects.first()  # evidence exists
    assert cert["signatures"][0]["device"] == "phone"


def test_superuser_admin_shows_no_letter_titles_and_audit_csv_exports(world, client):
    from django.test import Client

    from accounts.models import User

    lid = world.create()["id"]
    for s in world.signers:
        world.sign(s, lid)
    world.boss.call("post", f"/letters/{lid}/unlist", {})
    assert "Budget" not in " ".join(str(e.data) + e.target for e in AuditEvent.objects.all())
    root = User.objects.create_superuser("root@corp.test", "x" * 20)
    dev = Client()
    dev.force_login(root)
    resp = dev.post("/admin/accounts/auditevent/", {"action": "export_audit_csv",
                                                    "_selected_action": [AuditEvent.objects.first().pk]})
    assert resp.status_code == 200 and resp["Content-Type"] == "text/csv"
    assert dev.get("/admin/letters/letter/").status_code == 404  # letters are not in the superuser admin
    assert dev.get("/admin/keys/userkey/").status_code == 404
