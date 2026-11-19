"""Letters v2: referrals, linked tasks and paraphs."""
from accounts.models import Permission
from letters.models import Paraph, Referral
from letters.tests.conftest import *  # noqa: F401,F403  (world, dev, PIN)
from letters.tests.test_v2_boxes import ids, publish


def refer(world, who, letter_id, targets, note="please decide"):
    return world.dev(who).call("post", f"/letters/{letter_id}/refer", {"user_ids": [t.id for t in targets], "note": note})


# --- referrals -------------------------------------------------------------------------------------------------


def test_referee_reads_private_letter_but_cannot_sign(world, make_user, dev):
    guest = make_user("guest@corp.test")  # no letter.see, no letter.sign
    world.d[guest.email] = dev(guest)
    letter = world.create(visibility="private")
    assert world.d[guest.email].call("get", f"/letters/{letter['id']}").status_code == 404
    resp = refer(world, world.alice, letter["id"], [guest])
    assert resp.status_code == 201, resp.content
    assert resp.data[0]["status"] == "pending" and resp.data[0]["note"]["text"] == "please decide"
    got = world.d[guest.email].call("get", f"/letters/{letter['id']}")
    assert got.status_code == 200 and got.data["body"]["text"].startswith("Dear")
    assert ids(world.d[guest.email].call("get", "/letters?box=inbox")) == [letter["id"]]
    signed = world.d[guest.email].call("post", f"/letters/{letter['id']}/sign",
                                       {"decision": "approved", "note": "", "pin": PIN})
    assert signed.status_code == 403
    assert world.d[guest.email].call("get", f"/letters/{letter['id']}").data["referral_count"] == 1


def test_who_may_refer(world):
    letter = world.create(visibility="private")
    assert refer(world, world.outsider, letter["id"], [world.viewer]).status_code == 404  # cannot see it
    public = world.create(visibility="public", mode="now")
    assert refer(world, world.outsider, public["id"], [world.viewer]).status_code == 403  # sees, not a participant
    assert refer(world, world.signers[0], letter["id"], [world.viewer]).status_code == 201
    assert refer(world, world.viewer, letter["id"], [world.outsider]).status_code == 201  # referees may refer on
    assert refer(world, world.alice, world.create(send=False)["id"], [world.viewer]).status_code == 409  # draft


def test_refer_validation_and_duplicates(world, make_user):
    letter = world.create(visibility="private")
    gone = make_user("gone@corp.test", active=False)
    assert refer(world, world.alice, letter["id"], [gone]).status_code == 422
    assert refer(world, world.alice, letter["id"], [world.viewer]).status_code == 201
    again = refer(world, world.alice, letter["id"], [world.viewer])
    assert again.status_code == 201 and again.data == []  # already pending: nothing new
    assert Referral.objects.filter(letter_id=letter["id"]).count() == 1


def test_respond_flow_notifies_and_blocks_others(world):
    letter = world.create(visibility="private")
    rid = refer(world, world.alice, letter["id"], [world.viewer]).data[0]["id"]
    assert world.dev(world.outsider).call("post", f"/referrals/{rid}/respond", {"status": "done"}).status_code == 404
    bad = world.dev(world.viewer).call("post", f"/referrals/{rid}/respond", {"status": "maybe"})
    assert bad.status_code == 422
    ok = world.dev(world.viewer).call("post", f"/referrals/{rid}/respond", {"status": "declined", "note": "no time"})
    assert ok.status_code == 200 and ok.data["status"] == "declined" and ok.data["response_note"]["text"] == "no time"
    assert ok.data["responded_at"]
    assert world.dev(world.viewer).call("post", f"/referrals/{rid}/respond", {"status": "done"}).status_code == 409
    listed = world.alice_d.call("get", f"/letters/{letter['id']}/referrals")
    assert [r["status"] for r in listed.data] == ["declined"]
    assert world.dev(world.outsider).call("get", f"/letters/{letter['id']}/referrals").status_code == 404
    # the referee keeps access after answering
    assert world.dev(world.viewer).call("get", f"/letters/{letter['id']}").status_code == 200


def test_referral_audit_and_events_carry_ids_only(world):
    from accounts.models import AuditEvent
    from workspace.models import Event

    letter = world.create(visibility="private")
    rid = refer(world, world.alice, letter["id"], [world.viewer], note="secret-note").data[0]["id"]
    world.dev(world.viewer).call("post", f"/referrals/{rid}/respond", {"status": "done", "note": "secret-answer"})
    blob = " ".join(str(e.data) + e.target for e in AuditEvent.objects.filter(action__startswith="referral")
                    | AuditEvent.objects.filter(action="letter_referred"))
    assert "secret" not in blob and "Budget" not in blob and AuditEvent.objects.filter(action="letter_referred").exists()
    kinds = set(Event.objects.filter(module="letters").values_list("kind", flat=True))
    assert {"letter.referred", "letter.referral_responded"} <= kinds
    assert not any("secret" in str(e.data) for e in Event.objects.all())
    referred = Event.objects.get(kind="letter.referred")
    assert world.viewer.id in set(referred.recipients.values_list("user_id", flat=True))


# --- linked tasks ----------------------------------------------------------------------------------------------


def make_task(dev, title="Prepare budget"):
    resp = dev.call("post", "/tasks", {"title": title})
    assert resp.status_code == 201, resp.content
    return resp.data


def test_task_link_visibility(world, make_user, dev):
    world.alice.grants.add(*Permission.objects.filter(code="task.create"))
    task = make_task(world.alice_d)
    letter = world.create(visibility="private", viewers=[world.viewer])
    lid = letter["id"]
    assert world.alice_d.call("post", f"/letters/{lid}/tasks", {"task_id": task["id"]}).status_code == 201
    got = world.alice_d.call("get", f"/letters/{lid}").data
    assert [t["id"] for t in got["tasks"]] == [task["id"]]
    # a signer sees the letter but not alice's personal task: nothing shown, cannot link it, cannot list it
    signer = world.dev(world.signers[0])
    assert signer.call("get", f"/letters/{lid}").data["tasks"] == []
    assert signer.call("get", f"/letters/{lid}/tasks").data == []
    assert signer.call("post", f"/letters/{lid}/tasks", {"task_id": task["id"]}).status_code == 404
    assert signer.call("delete", f"/letters/{lid}/tasks/{task['id']}").status_code == 404
    # a task alice cannot see, an invisible letter
    stranger = make_user("t@corp.test", grants=("task.create", "letter.see"))
    theirs = make_task(dev(stranger))
    assert world.alice_d.call("post", f"/letters/{lid}/tasks", {"task_id": theirs["id"]}).status_code == 404
    assert world.dev(world.outsider).call("get", f"/letters/{lid}/tasks").status_code == 404


def test_task_unlink_deactivates_and_relink_works(world):
    world.alice.grants.add(*Permission.objects.filter(code="task.create"))
    task = make_task(world.alice_d)
    lid = world.create()["id"]
    world.alice_d.call("post", f"/letters/{lid}/tasks", {"task_id": task["id"]})
    assert world.alice_d.call("delete", f"/letters/{lid}/tasks/{task['id']}").status_code == 204
    assert world.alice_d.call("get", f"/letters/{lid}/tasks").data == []
    assert world.alice_d.call("delete", f"/letters/{lid}/tasks/{task['id']}").status_code == 404
    assert world.alice_d.call("post", f"/letters/{lid}/tasks", {"task_id": task["id"]}).status_code == 201
    assert len(world.alice_d.call("get", f"/letters/{lid}/tasks").data) == 1


# --- paraph ----------------------------------------------------------------------------------------------------


def paraph(world, who, lid, pin=PIN):
    return world.dev(who).call("post", f"/letters/{lid}/paraph", {"pin": pin})


def test_paraph_pin_once_and_certificate(world):
    letter = world.create(visibility="private", viewers=[world.viewer])
    lid = letter["id"]
    resp = paraph(world, world.signers[0], lid)
    assert resp.status_code == 201, resp.content
    assert resp.data["method"] == "pin" and resp.data["payload"]["kind"] == "paraph"
    assert resp.data["payload"]["v"] == 3 and resp.data["payload"]["signer"]["userId"] == world.signers[0].id
    assert paraph(world, world.signers[0], lid).status_code == 409  # once only
    assert paraph(world, world.signers[1], lid, pin="000000").status_code == 403
    assert len(world.alice_d.call("get", f"/letters/{lid}").data["paraphs"]) == 1
    cert = world.alice_d.call("get", f"/letters/{lid}/certificate").data
    assert [p["verified"] for p in cert["paraphs"]] == [True] and cert["paraphs_verified"] is True


def test_paraph_who_and_when(world):
    lid = world.create(visibility="private", viewers=[world.viewer], mode="after_sign")["id"]
    assert paraph(world, world.outsider, lid).status_code == 404
    assert paraph(world, world.alice, lid).status_code == 403  # the creator is not signer/viewer/referee
    pub = world.create(visibility="public", mode="now")["id"]
    assert paraph(world, world.outsider, pub).status_code == 403  # sees it but is not involved
    draft = world.create(send=False)["id"]
    assert paraph(world, world.signers[0], draft).status_code == 404
    refer(world, world.alice, lid, [world.outsider])
    assert paraph(world, world.outsider, lid).status_code == 201  # referee
    done = publish(world, visibility="public", viewers=[])
    assert paraph(world, world.signers[0], done["id"]).status_code == 201  # published letters can be initialled
    rejected = world.create()
    world.sign(world.signers[0], rejected["id"], decision="rejected")
    assert paraph(world, world.signers[1], rejected["id"]).status_code == 409


def test_paraph_biometric_needs_a_biometric_session(world, dev):
    lid = world.create()["id"]
    plain = world.dev(world.signers[0]).call("post", f"/letters/{lid}/paraph-biometric")
    assert plain.status_code == 403
    bio = dev(world.signers[1], "bio", biometric=True)
    resp = bio.call("post", f"/letters/{lid}/paraph-biometric")
    assert resp.status_code == 201 and resp.data["method"] == "biometric"
    assert resp.data["payload"]["deviceName"] == "bio"


def test_paraph_pin_failures_are_rate_limited_and_not_burned_by_outsiders(world):
    lid = world.create(visibility="private")["id"]
    for _ in range(6):
        paraph(world, world.outsider, lid, pin="000000")  # 404: never counts
    for _ in range(5):
        assert paraph(world, world.signers[0], lid, pin="111111").status_code == 403
    assert paraph(world, world.signers[0], lid, pin="111111").status_code == 429


def test_forged_paraph_seal_fails_certificate(world):
    """A valid seal over a payload of another kind or letter must not verify (rows are immutable, so forge in memory)."""
    from types import SimpleNamespace

    from core import cryptoutil
    from letters import paraphs

    lid = world.create()["id"]
    paraph(world, world.signers[0], lid)
    row = Paraph.objects.select_related("user").get(letter_id=lid)
    good = paraphs.certificate_rows(row.letter, row.payload["contentHash"])
    assert good[0]["verified"] is True
    for tweak in ({"kind": "signature"}, {"letterId": "00000000-0000-0000-0000-000000000000"},
                  {"signer": {**row.payload["signer"], "userId": 999}}):
        row.payload = {**row.payload, **tweak}
        row.seal = cryptoutil.seal_payload(row.payload)  # validly sealed, wrongly described
        fake = SimpleNamespace(id=row.letter_id, paraphs=SimpleNamespace(select_related=lambda *a: SimpleNamespace(
            order_by=lambda *b: [row])))
        assert paraphs.certificate_rows(fake, row.payload["contentHash"])[0]["verified"] is False
    row.seal = "AAAA"
    fake = SimpleNamespace(id=row.letter_id, paraphs=SimpleNamespace(select_related=lambda *a: SimpleNamespace(
        order_by=lambda *b: [row])))
    assert paraphs.certificate_rows(fake, row.payload["contentHash"])[0]["verified"] is False


def test_paraph_rows_are_immutable_in_the_database(world):
    import pytest
    from django.db import DatabaseError

    lid = world.create()["id"]
    paraph(world, world.signers[0], lid)
    with pytest.raises(DatabaseError):
        Paraph.objects.filter(letter_id=lid).update(method="biometric")
    with pytest.raises(DatabaseError):
        Paraph.objects.filter(letter_id=lid).delete()
