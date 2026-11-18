import pytest
from django.contrib.auth.hashers import check_password, make_password

from accounts.models import AuditEvent, Session, User
from accounts.tests.conftest import PASSWORD

PIN_URL = "/me/signing-pin"


def login(api, user, **extra):
    resp = api.call("post", "/auth/login", {"email": user.email, "password": PASSWORD, "device_name": "d", **extra})
    assert resp.status_code == 200
    return resp.data


def test_pin_set_requires_login_password_and_is_stored_hashed(api, make_user):
    user = make_user("p@corp.test")
    session = login(api, user)
    assert session["user"]["has_signing_pin"] is False
    token = session["access"]
    assert api.call("put", PIN_URL, {"pin": "123456", "password": "nope"}, token=token).status_code == 403
    ok = api.call("put", PIN_URL, {"pin": "123456", "password": PASSWORD}, token=token)
    assert ok.status_code == 200
    user = User.objects.get(pk=user.pk)
    assert user.signing_pin_hash and "123456" not in user.signing_pin_hash
    assert check_password("123456", user.signing_pin_hash)
    assert api.call("get", "/me", token=token).data["has_signing_pin"] is True
    assert AuditEvent.objects.filter(action="signing_pin_set", actor=user).exists()


@pytest.mark.parametrize("pin", ["12345", "1234567", "12345a", "abcdef", "", "12 456", "１２３４５６"])
def test_pin_must_be_exactly_six_digits(api, make_user, pin):
    user = make_user("p@corp.test")
    token = login(api, user)["access"]
    assert api.call("put", PIN_URL, {"pin": pin, "password": PASSWORD}, token=token).status_code == 422


def test_pin_can_be_changed_and_the_password_is_rate_limited(api, make_user):
    user = make_user("p@corp.test")
    token = login(api, user)["access"]
    api.call("put", PIN_URL, {"pin": "111111", "password": PASSWORD}, token=token)
    api.call("put", PIN_URL, {"pin": "222222", "password": PASSWORD}, token=token)
    assert check_password("222222", User.objects.get(pk=user.pk).signing_pin_hash)
    for _ in range(10):
        assert api.call("put", PIN_URL, {"pin": "333333", "password": "wrong"}, token=token).status_code == 403
    assert api.call("put", PIN_URL, {"pin": "333333", "password": PASSWORD}, token=token).status_code == 429
    assert check_password("222222", User.objects.get(pk=user.pk).signing_pin_hash)


def test_pin_endpoint_needs_authentication(api):
    assert api.call("put", PIN_URL, {"pin": "123456", "password": "x"}).status_code == 401


def with_pin(user, pin="123456"):
    user.signing_pin_hash = make_password(pin)
    user.save(update_fields=["signing_pin_hash"])
    return user


def patch(api, token, body):
    return api.call("patch", "/me/sessions/current", body, token=token)


def test_login_ignores_the_biometric_flag(api, make_user):
    user = make_user("b@corp.test")
    plain = login(api, user)
    bio = login(api, user, biometric=True, device_name="fp")
    rows = {s["id"]: s for s in api.call("get", "/me/sessions", token=bio["access"]).data}
    assert rows[plain["session_id"]]["biometric"] is False
    assert rows[bio["session_id"]]["biometric"] is False and rows[bio["session_id"]]["current"] is True


def test_enabling_biometric_needs_the_pin(api, make_user):
    token = login(api, with_pin(make_user("b@corp.test")))["access"]
    resp = patch(api, token, {"biometric": True})
    assert resp.status_code == 422 and "pin" in str(resp.content).lower()
    assert patch(api, token, {"biometric": True, "pin": None}).status_code == 422
    ok = patch(api, token, {"biometric": True, "pin": "123456"})
    assert ok.status_code == 200 and ok.data["biometric"] is True and ok.data["current"] is True
    assert AuditEvent.objects.filter(action="session_biometric_enabled").count() == 1


def test_wrong_pin_is_403_counted_and_locks(api, make_user):
    user = with_pin(make_user("b@corp.test"))
    token = login(api, user)["access"]
    for _ in range(5):
        assert patch(api, token, {"biometric": True, "pin": "000000"}).status_code == 403
    assert AuditEvent.objects.filter(action="sign_pin_failed", actor=user).count() == 5
    assert patch(api, token, {"biometric": True, "pin": "123456"}).status_code == 429
    assert Session.objects.get(pk=login_session(api, token)).biometric is False


def login_session(api, token):
    return next(s["id"] for s in api.call("get", "/me/sessions", token=token).data if s["current"])


def test_enabling_without_a_signing_pin_is_409(api, make_user):
    token = login(api, make_user("b@corp.test"))["access"]
    assert patch(api, token, {"biometric": True, "pin": "123456"}).status_code == 409


def test_correct_pin_refunds_its_attempt(api, make_user):
    token = login(api, with_pin(make_user("b@corp.test")))["access"]
    for _ in range(8):
        assert patch(api, token, {"biometric": True, "pin": "123456"}).status_code == 200
        assert patch(api, token, {"biometric": False}).status_code == 200


def test_disabling_needs_nothing_and_enabling_again_is_a_noop_without_pin(api, make_user):
    token = login(api, with_pin(make_user("b@corp.test")))["access"]
    assert patch(api, token, {"biometric": False}).data["biometric"] is False  # already false: fine
    patch(api, token, {"biometric": True, "pin": "123456"})
    again = patch(api, token, {"biometric": True})
    assert again.status_code == 200 and again.data["biometric"] is True
    assert AuditEvent.objects.filter(action="session_biometric_enabled").count() == 1
    assert patch(api, token, {"biometric": False}).data["biometric"] is False
    assert patch(api, token, {}).status_code == 422


def test_disabling_works_for_a_user_without_a_pin(api, make_user):
    token = login(api, make_user("b@corp.test"))["access"]
    assert patch(api, token, {"biometric": False}).status_code == 200
