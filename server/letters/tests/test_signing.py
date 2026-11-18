from django.contrib.auth.hashers import make_password

from accounts.models import AuditEvent
from letters.models import Signature
from accounts.tests.conftest import PASSWORD
from letters.tests.conftest import PIN


def test_wrong_pin_is_403_and_locks_out_after_five_failures(world):
    lid = world.create()["id"]
    s0 = world.signers[0]
    for _ in range(5):
        resp = world.sign(s0, lid, pin="000000")
        assert resp.status_code == 403 and resp.data["detail"] == "Wrong signing PIN"
    assert world.sign(s0, lid).status_code == 429  # even the right PIN is refused while locked out
    assert world.sign(world.signers[1], lid).status_code == 200  # the lockout is per user
    assert AuditEvent.objects.filter(action="sign_pin_failed", actor=s0).count() == 5
    assert not Signature.objects.filter(signer=s0).exists()


def test_correct_pins_are_never_throttled_but_failures_stay_counted(world):
    s0 = world.signers[0]
    letters = [world.create()["id"] for _ in range(7)]
    for lid in letters[:6]:  # more successful signatures than the failure limit
        assert world.sign(s0, lid).status_code == 200
    for _ in range(4):
        world.sign(s0, letters[6], pin="000000")
    assert world.sign(s0, letters[6]).status_code == 200  # 5th attempt in the window, still allowed
    other = world.create()["id"]
    for _ in range(5):
        world.sign(world.signers[1], other, pin="000000")
    assert world.sign(world.signers[1], other).status_code == 429  # the failures were not refunded


def test_the_attempt_is_counted_before_the_pin_is_verified(world, monkeypatch):
    from accounts import ratelimit
    from letters import signing

    s0, seen = world.signers[0], []

    def spy(pin, hashed):
        seen.append(ratelimit.count(signing.PIN_SCOPE, str(s0.id)))
        return False

    monkeypatch.setattr(signing, "check_password", spy)
    assert world.sign(s0, world.create()["id"]).status_code == 403
    assert seen == [1]


def test_the_session_cap_holds_even_when_the_user_counter_is_reset(world):
    from accounts import ratelimit
    from letters import signing

    s0 = world.signers[0]
    lid = world.create()["id"]
    for _ in range(signing.PIN_MAX_FAILURES_PER_SESSION):
        world.sign(s0, lid, pin="000000")
        if _ % signing.PIN_MAX_FAILURES == signing.PIN_MAX_FAILURES - 1:
            ratelimit.reset(signing.PIN_SCOPE, str(s0.id))  # what PUT /me/signing-pin does
    ratelimit.reset(signing.PIN_SCOPE, str(s0.id))
    assert world.sign(s0, lid).status_code == 429


def test_a_signer_whose_sign_grant_was_revoked_cannot_sign(world):
    s0 = world.signers[0]
    lid = world.create()["id"]
    s0.grants.clear()
    assert world.sign(s0, lid).status_code == 403
    assert not Signature.objects.filter(signer=s0).exists()


def test_invisible_or_missing_letters_are_404_for_every_sign_entry_point(world, dev):
    lid = world.create(visibility="private", viewers=[world.viewer])["id"]
    out = world.dev(world.outsider)
    bio = dev(world.outsider, "bio", biometric=True)
    missing = "00000000-0000-0000-0000-000000000000"
    body = {"decision": "approved", "note": ""}
    for target in (lid, missing):
        assert out.call("post", f"/letters/{target}/sign", {**body, "pin": PIN}).status_code == 404
        assert bio.call("post", f"/letters/{target}/sign-biometric", body).status_code == 404
        req = {**body, "approver_session_id": bio.session_id}
        assert bio.call("post", f"/letters/{target}/sign-requests", req).status_code == 404


def test_a_visible_letter_the_caller_does_not_sign_is_403(world):
    lid = world.create(visibility="private", viewers=[world.viewer], mode="now")["id"]
    assert world.sign(world.viewer, lid).status_code == 403


def test_certificate_is_not_all_verified_without_signatures(world):
    lid = world.create()["id"]
    cert = world.alice_d.call("get", f"/letters/{lid}/certificate").data
    assert cert["signatures"] == [] and cert["all_verified"] is False


def test_signing_without_a_pin_is_409(world, make_user, dev):
    nopin = make_user("nopin@corp.test", grants=("letter.sign",))
    world.d[nopin.email] = dev(nopin)
    lid = world.create(signers=[nopin])["id"]
    resp = world.sign(nopin, lid)
    assert resp.status_code == 409 and resp.data["detail"] == "Set your signing PIN first"


def test_non_signers_get_403_and_cannot_burn_pin_attempts(world):
    lid = world.create(mode="now")["id"]
    for _ in range(8):
        assert world.sign(world.viewer, lid, pin="000000").status_code == 403
    assert not AuditEvent.objects.filter(action="sign_pin_failed", actor=world.viewer).exists()


def test_cannot_sign_twice_and_decision_is_final(world):
    lid = world.create()["id"]
    assert world.sign(world.signers[0], lid, "approved", "ok").status_code == 200
    assert world.sign(world.signers[0], lid, "rejected").status_code == 409
    sig = world.alice_d.call("get", f"/letters/{lid}").data["signatures"][0]
    assert sig["note"] == "ok" and sig["decision"] == "approved"


def test_serial_order_applies_to_every_method(world, dev):
    bio = dev(world.signers[1], "bio", biometric=True)
    lid = world.create(order="serial")["id"]
    body = {"decision": "approved", "note": ""}
    assert bio.call("post", f"/letters/{lid}/sign-biometric", body).status_code == 409
    assert world.sign(world.signers[1], lid).status_code == 409
    assert world.sign(world.signers[0], lid).status_code == 200
    assert bio.call("post", f"/letters/{lid}/sign-biometric", body).status_code == 200


def test_sign_biometric_requires_a_biometric_session(world, dev):
    lid = world.create()["id"]
    body = {"decision": "approved", "note": "fine"}
    plain = world.dev(world.signers[0])
    assert plain.call("post", f"/letters/{lid}/sign-biometric", body).status_code == 403
    bio = dev(world.signers[0], "fingerprint-phone", biometric=True)
    resp = bio.call("post", f"/letters/{lid}/sign-biometric", body)
    assert resp.status_code == 200
    sig = world.alice_d.call("get", f"/letters/{lid}").data["signatures"][0]
    assert sig["method"] == "biometric" and sig["device_name"] == "fingerprint-phone"
    assert sig["payload"]["sessionId"] == bio.session_id
    assert AuditEvent.objects.get(action="letter_signed").data["method"] == "biometric"


def test_biometric_flag_can_be_switched_on_for_the_current_session(world):
    lid = world.create()["id"]
    d = world.dev(world.signers[0])
    body = {"decision": "approved", "note": ""}
    assert d.call("post", f"/letters/{lid}/sign-biometric", body).status_code == 403
    assert d.call("patch", "/me/sessions/current", {"biometric": True}).status_code == 422
    patched = d.call("patch", "/me/sessions/current", {"biometric": True, "pin": PIN})
    assert patched.status_code == 200 and patched.data["biometric"] is True and patched.data["current"] is True
    assert d.call("post", f"/letters/{lid}/sign-biometric", body).status_code == 200


def test_a_rejection_by_pin_or_biometric_closes_the_letter(world):
    lid = world.create()["id"]
    assert world.sign(world.signers[0], lid, "rejected", "no budget").data["status"] == "rejected"
    sig = Signature.objects.get()
    assert sig.decision == "rejected" and sig.payload["note"] == "no budget"


def test_pin_hash_can_be_replaced_directly_and_old_pin_stops_working(world):
    lid = world.create()["id"]
    s0 = world.signers[0]
    s0.signing_pin_hash = make_password("654321")
    s0.save(update_fields=["signing_pin_hash"])
    assert world.sign(s0, lid, pin=PIN).status_code == 403
    assert world.sign(s0, lid, pin="654321").status_code == 200


def test_login_with_biometric_true_gives_a_session_that_cannot_sign_biometrically(world, api):
    s0 = world.signers[0]
    lid = world.create()["id"]
    resp = api.call("post", "/auth/login", {"email": s0.email, "password": PASSWORD, "biometric": True})
    token = resp.data["access"]
    body = {"decision": "approved", "note": ""}
    assert api.call("post", f"/letters/{lid}/sign-biometric", body, token=token).status_code == 403


def test_a_token_holder_without_the_pin_cannot_become_an_approver(world, api, dev):
    user = world.signers[0]
    laptop = dev(user, "laptop")
    login = api.call("post", "/auth/login", {"email": user.email, "password": PASSWORD, "biometric": True}).data
    thief = login["access"]
    assert api.call("patch", "/me/sessions/current", {"biometric": True, "pin": "999999"}, token=thief).status_code == 403
    lid = world.create()["id"]
    sr = laptop.call("post", f"/letters/{lid}/sign-requests",
                     {"decision": "approved", "note": "", "approver_session_id": login["session_id"]})
    assert sr.status_code == 422


def test_enrolled_session_can_be_an_approver_and_disabling_removes_it(world, dev):
    user = world.signers[0]
    laptop, phone = dev(user, "laptop"), dev(user, "phone", biometric=True)
    lid = world.create()["id"]
    body = {"decision": "approved", "note": "", "approver_session_id": phone.session_id}
    assert laptop.call("post", f"/letters/{lid}/sign-requests", body).status_code == 201
    assert phone.call("patch", "/me/sessions/current", {"biometric": False}).status_code == 200
