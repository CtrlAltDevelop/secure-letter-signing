from datetime import timedelta

import pytest
from django.utils import timezone

from accounts.models import AuditEvent, Session
from letters.models import SignRequest, Signature


@pytest.fixture
def pair(world, dev):
    """signer s0 with a plain session (laptop) and a biometric session (phone)."""
    user = world.signers[0]
    laptop, phone = dev(user, "laptop"), dev(user, "phone", biometric=True)
    return user, laptop, phone


def ask(world, laptop, phone, lid, decision="approved", note="please"):
    return laptop.call("post", f"/letters/{lid}/sign-requests",
                       {"decision": decision, "note": note, "approver_session_id": phone.session_id})


def test_request_approve_signs_with_the_approvers_session_and_device(world, pair):
    user, laptop, phone = pair
    lid = world.create()["id"]
    resp = ask(world, laptop, phone, lid)
    assert resp.status_code == 201
    rid = resp.data["id"]
    assert resp.data["status"] == "pending" and resp.data["letter_title"] == "Budget 2027"
    assert resp.data["requester_device_name"] == "laptop" and resp.data["approver_session_id"] == phone.session_id
    inbox = phone.call("get", "/sign-requests/incoming").data
    assert [r["id"] for r in inbox] == [rid]
    assert laptop.call("get", "/sign-requests/incoming").data == []  # only the approver session sees it
    done = phone.call("post", f"/sign-requests/{rid}/approve")
    assert done.status_code == 200 and done.data["status"] == "approved" and done.data["resolved_at"]
    sig = world.alice_d.call("get", f"/letters/{lid}").data["signatures"][0]
    assert sig["method"] == "biometric" and sig["device_name"] == "phone"
    assert sig["payload"]["sessionId"] == phone.session_id and sig["note"] == "please"
    assert laptop.call("get", f"/sign-requests/{rid}").data["status"] == "approved"
    assert phone.call("get", "/sign-requests/incoming").data == []
    actions = list(AuditEvent.objects.values_list("action", flat=True))
    assert "sign_requested" in actions and "letter_signed" in actions


def test_request_can_carry_a_rejection(world, pair):
    _, laptop, phone = pair
    lid = world.create()["id"]
    rid = ask(world, laptop, phone, lid, "rejected", "no").data["id"]
    assert phone.call("post", f"/sign-requests/{rid}/approve").status_code == 200
    assert world.alice_d.call("get", f"/letters/{lid}").data["status"] == "rejected"


def test_requester_session_and_other_users_cannot_approve(world, pair, dev):
    user, laptop, phone = pair
    lid = world.create()["id"]
    rid = ask(world, laptop, phone, lid).data["id"]
    assert laptop.call("post", f"/sign-requests/{rid}/approve").status_code == 403
    other_phone = dev(world.signers[1], "other", biometric=True)
    assert other_phone.call("post", f"/sign-requests/{rid}/approve").status_code == 404
    assert other_phone.call("get", f"/sign-requests/{rid}").status_code == 404
    third = dev(user, "tablet", biometric=True)  # same user, biometric, but not the chosen approver
    assert third.call("post", f"/sign-requests/{rid}/approve").status_code == 403
    assert not Signature.objects.exists()


def test_approver_must_be_another_live_biometric_session_of_the_same_user(world, pair, dev):
    user, laptop, phone = pair
    lid = world.create()["id"]
    plain2 = dev(user, "plain2")
    assert ask(world, laptop, plain2, lid).status_code == 422  # not biometric
    assert ask(world, phone, phone, lid).status_code == 422  # not another session
    foreign = dev(world.signers[1], "x", biometric=True)
    assert ask(world, laptop, foreign, lid).status_code == 422  # someone else's
    Session.objects.filter(pk=phone.session_id).update(revoked_at=timezone.now())
    assert ask(world, laptop, phone, lid).status_code == 422  # revoked
    missing = laptop.call("post", f"/letters/{lid}/sign-requests", {
        "decision": "approved", "note": "", "approver_session_id": "00000000-0000-0000-0000-000000000000"})
    assert missing.status_code == 422


def test_decline_and_cancel(world, pair):
    _, laptop, phone = pair
    lid = world.create()["id"]
    rid = ask(world, laptop, phone, lid).data["id"]
    assert laptop.call("post", f"/sign-requests/{rid}/decline").status_code == 403
    assert phone.call("post", f"/sign-requests/{rid}/cancel").status_code == 403
    declined = phone.call("post", f"/sign-requests/{rid}/decline")
    assert declined.data["status"] == "declined"
    assert phone.call("post", f"/sign-requests/{rid}/approve").status_code == 409
    assert AuditEvent.objects.filter(action="sign_request_declined").exists()
    rid2 = ask(world, laptop, phone, lid).data["id"]
    assert laptop.call("post", f"/sign-requests/{rid2}/cancel").data["status"] == "cancelled"
    assert phone.call("post", f"/sign-requests/{rid2}/approve").status_code == 409
    assert phone.call("get", "/sign-requests/incoming").data == []


def test_a_new_request_cancels_the_older_pending_one(world, pair):
    _, laptop, phone = pair
    lid = world.create()["id"]
    first = ask(world, laptop, phone, lid).data["id"]
    second = ask(world, laptop, phone, lid, "rejected").data["id"]
    assert laptop.call("get", f"/sign-requests/{first}").data["status"] == "cancelled"
    assert [r["id"] for r in phone.call("get", "/sign-requests/incoming").data] == [second]


def test_expired_requests_are_reported_expired_and_cannot_be_approved(world, pair):
    _, laptop, phone = pair
    lid = world.create()["id"]
    rid = ask(world, laptop, phone, lid).data["id"]
    SignRequest.objects.filter(pk=rid).update(expires_at=timezone.now() - timedelta(seconds=1))
    assert laptop.call("get", f"/sign-requests/{rid}").data["status"] == "expired"
    assert phone.call("get", "/sign-requests/incoming").data == []
    assert phone.call("post", f"/sign-requests/{rid}/approve").status_code == 409
    assert not Signature.objects.exists()


def test_new_request_expires_in_five_minutes(world, pair):
    _, laptop, phone = pair
    resp = ask(world, laptop, phone, world.create()["id"])
    from datetime import datetime

    delta = datetime.fromisoformat(resp.data["expires_at"]) - datetime.fromisoformat(resp.data["created_at"])
    assert delta == timedelta(minutes=5)


def test_signing_rules_are_rechecked_on_request_and_approval(world, pair):
    user, laptop, phone = pair
    serial = world.create(order="serial", signers=[world.signers[1], user])["id"]
    assert ask(world, laptop, phone, serial).status_code == 409  # not my turn
    lid = world.create()["id"]
    rid = ask(world, laptop, phone, lid).data["id"]
    assert world.sign(user, lid).status_code == 200  # signs by PIN meanwhile
    assert phone.call("post", f"/sign-requests/{rid}/approve").status_code == 409  # already decided
    world.alice_d.call("post", f"/letters/{lid}/cancel")
    outsider = world.dev(world.viewer)
    assert outsider.call("post", f"/letters/{lid}/sign-requests", {
        "decision": "approved", "note": "", "approver_session_id": phone.session_id}).status_code == 404  # cannot see it


def test_approval_needs_the_session_to_still_be_biometric(world, pair):
    _, laptop, phone = pair
    lid = world.create()["id"]
    rid = ask(world, laptop, phone, lid).data["id"]
    Session.objects.filter(pk=phone.session_id).update(biometric=False)
    assert phone.call("post", f"/sign-requests/{rid}/approve").status_code == 403


def test_cancelled_or_superseded_requests_cannot_be_approved_after_the_lock(world, pair):
    user, laptop, phone = pair
    lid = world.create()["id"]
    first = ask(world, laptop, phone, lid).data["id"]
    second = ask(world, laptop, phone, lid).data["id"]  # supersedes the first
    assert phone.call("post", f"/sign-requests/{first}/approve").status_code == 409
    assert laptop.call("post", f"/sign-requests/{second}/cancel").status_code == 200
    assert phone.call("post", f"/sign-requests/{second}/approve").status_code == 409
    assert phone.call("post", f"/sign-requests/{second}/decline").status_code == 409
    assert laptop.call("post", f"/sign-requests/{first}/cancel").status_code == 409
    assert not Signature.objects.exists()
