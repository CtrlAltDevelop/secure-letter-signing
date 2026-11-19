import time
from datetime import timedelta

from django.utils import timezone

from accounts import totp, twofactor
from accounts.models import AuditEvent, LoginEvent, RecoveryCode, Session, User

from .conftest import PASSWORD


def bearer(api, email):
    return api.login(email)["access"]


def current_code(user, ahead=0):
    return totp.code_at(twofactor.secret_of(user), time.time() + 30 * ahead)


def enable(api, user, token):
    secret = api.call("post", "/me/2fa", token=token).data["secret"]
    user.refresh_from_db()
    assert totp.code_at(secret) == current_code(user)
    resp = api.call("post", "/me/2fa/confirm", {"code": current_code(user)}, token)
    assert resp.status_code == 200, resp.content
    return resp.data["recovery_codes"]


def test_setup_gives_secret_and_uri_and_stores_it_encrypted(api, make_user):
    user = make_user("a@corp.test")
    token = bearer(api, user.email)
    assert api.call("get", "/me/2fa", token=token).data == {
        "enabled": False, "setup_pending": False, "recovery_codes_left": 0, "required": False}
    out = api.call("post", "/me/2fa", token=token).data
    assert out["otpauth_uri"].startswith("otpauth://totp/") and f"secret={out['secret']}" in out["otpauth_uri"]
    user.refresh_from_db()
    assert out["secret"] not in user.totp_secret and not user.totp_enabled
    assert api.call("get", "/me/2fa", token=token).data["setup_pending"] is True


def test_confirm_needs_the_right_code_then_enables_with_ten_recovery_codes(api, make_user):
    user = make_user("a@corp.test")
    token = bearer(api, user.email)
    assert api.call("post", "/me/2fa/confirm", {"code": "123456"}, token).status_code == 409  # no setup yet
    api.call("post", "/me/2fa", token=token)
    assert api.call("post", "/me/2fa/confirm", {"code": "000000"}, token).status_code == 403
    user.refresh_from_db()
    codes = api.call("post", "/me/2fa/confirm", {"code": current_code(user)}, token).data["recovery_codes"]
    assert len(set(codes)) == 10 and RecoveryCode.objects.filter(user=user).count() == 10
    assert all(c not in row.hash for c in codes for row in RecoveryCode.objects.all())  # hashed
    assert api.call("get", "/me/2fa", token=token).data["recovery_codes_left"] == 10
    assert api.call("post", "/me/2fa", token=token).status_code == 409  # already on


def test_login_challenge_end_to_end_and_codes_are_single_use(api, make_user):
    user = make_user("a@corp.test")
    enable(api, user, bearer(api, user.email))
    first = api.call("post", "/auth/login", {"email": user.email, "password": PASSWORD})
    assert first.status_code == 200 and first.data["two_factor_required"] and "access" not in first.data
    code = current_code(user, ahead=1)
    done = api.call("post", "/auth/login/2fa", {"challenge": first.data["challenge"], "code": code, "device_name": "p"})
    assert done.status_code == 200 and done.data["user"]["two_factor_enabled"] is True and done.data["access"]
    assert api.call("get", "/me", token=done.data["access"]).status_code == 200
    # the challenge cannot be reused, and the same code is refused on a new challenge
    assert api.call("post", "/auth/login/2fa", {"challenge": first.data["challenge"], "code": code}).status_code == 401
    second = api.call("post", "/auth/login", {"email": user.email, "password": PASSWORD}).data["challenge"]
    assert api.call("post", "/auth/login/2fa", {"challenge": second, "code": code}).status_code == 401


def test_recovery_code_works_once(api, make_user):
    user = make_user("a@corp.test")
    codes = enable(api, user, bearer(api, user.email))
    for expected in (200, 401):
        ch = api.call("post", "/auth/login", {"email": user.email, "password": PASSWORD}).data["challenge"]
        got = api.call("post", "/auth/login/2fa", {"challenge": ch, "recovery_code": codes[0]})
        assert got.status_code == expected
    ch = api.call("post", "/auth/login", {"email": user.email, "password": PASSWORD}).data["challenge"]
    assert api.call("post", "/auth/login/2fa", {"challenge": ch, "recovery_code": codes[1].upper()}).status_code == 200
    assert twofactor.recovery_codes_left(user) == 8


def test_wrong_codes_lock_the_challenge_and_are_logged(api, make_user):
    user = make_user("a@corp.test")
    enable(api, user, bearer(api, user.email))
    ch = api.call("post", "/auth/login", {"email": user.email, "password": PASSWORD}).data["challenge"]
    statuses = [api.call("post", "/auth/login/2fa", {"challenge": ch, "code": "000000"}).status_code for _ in range(6)]
    assert statuses == [401] * 5 + [429]
    assert api.call("post", "/auth/login/2fa", {"challenge": ch, "code": current_code(user, 1)}).status_code == 429
    assert LoginEvent.objects.filter(user=user, success=False, reason="bad_code").count() == 5
    assert api.call("post", "/auth/login/2fa", {"challenge": "junk", "code": "1"}).status_code == 401


def test_disable_needs_password_and_code(api, make_user):
    user = make_user("a@corp.test")
    token = bearer(api, user.email)
    enable(api, user, token)
    assert api.call("post", "/me/2fa/disable", {"password": "nope", "code": current_code(user)}, token).status_code == 403
    assert api.call("post", "/me/2fa/disable", {"password": PASSWORD, "code": "000000"}, token).status_code == 403
    assert api.call("post", "/me/2fa/disable", {"password": PASSWORD}, token).status_code == 422
    assert api.call("post", "/me/2fa/disable", {"password": PASSWORD, "code": current_code(user)}, token).status_code == 200
    user.refresh_from_db()
    assert not user.totp_enabled and user.totp_secret == "" and twofactor.recovery_codes_left(user) == 0
    assert api.call("post", "/auth/login", {"email": user.email, "password": PASSWORD}).data["access"]
    assert {"two_factor_enabled", "two_factor_disabled"} <= set(AuditEvent.objects.values_list("action", flat=True))


def test_disable_is_rate_limited(api, make_user):
    user = make_user("a@corp.test")
    token = bearer(api, user.email)
    enable(api, user, token)
    codes = [api.call("post", "/me/2fa/disable", {"password": PASSWORD, "code": "000000"}, token).status_code for _ in range(11)]
    assert codes[:10] == [403] * 10 and codes[10] == 429


def test_regenerate_recovery_codes_replaces_the_old_ones(api, make_user):
    user = make_user("a@corp.test")
    token = bearer(api, user.email)
    old = enable(api, user, token)
    new = api.call("post", "/me/2fa/recovery-codes", {"password": PASSWORD, "recovery_code": old[0]}, token)
    assert new.status_code == 200 and len(new.data["recovery_codes"]) == 10
    ch = api.call("post", "/auth/login", {"email": user.email, "password": PASSWORD}).data["challenge"]
    assert api.call("post", "/auth/login/2fa", {"challenge": ch, "recovery_code": old[1]}).status_code == 401
    assert api.call("post", "/auth/login/2fa", {"challenge": ch, "recovery_code": new.data["recovery_codes"][0]}).status_code == 200


def test_company_requirement_flags_users_without_2fa(api, make_user, company):
    user = make_user("a@corp.test")
    company.require_2fa = True
    company.save()
    assert api.login(user.email)["two_factor_setup_required"] is True
    assert api.call("get", "/me/2fa", token=bearer(api, user.email)).data["required"] is True


def test_login_history_lists_own_successes_and_failures_newest_first(api, make_user, manager):
    a, b = make_user("a@corp.test"), make_user("b@corp.test")
    api.call("post", "/auth/login", {"email": b.email, "password": "wrong-pass"})
    api.call("post", "/auth/login", {"email": a.email, "password": "wrong-pass"})
    token = bearer(api, a.email)
    api.call("post", "/auth/login", {"email": "ghost@corp.test", "password": "x"})
    rows = api.call("get", "/me/login-history", token=token).data
    assert [(r["success"], r["reason"]) for r in rows] == [(True, ""), (False, "bad_password")]
    assert set(rows[0]) == {"id", "at", "ip", "user_agent", "device_name", "success", "reason"}
    assert api.call("get", "/me/login-history?limit=1&offset=1", token=token).data[0]["reason"] == "bad_password"
    assert len(api.call("get", "/me/login-history?limit=1", token=token).data) == 1
    assert api.call("get", "/me/login-history").status_code == 401


def test_manager_reads_any_users_history_others_cannot(api, make_user, manager):
    a = make_user("a@corp.test")
    api.call("post", "/auth/login", {"email": a.email, "password": "wrong-pass"})
    api.login(a.email)
    boss, plain = bearer(api, manager.email), bearer(api, a.email)
    got = api.call("get", f"/manage/users/{a.id}/login-history", token=boss)
    assert got.status_code == 200 and len(got.data) == 3
    assert api.call("get", f"/manage/users/{a.id}/login-history", token=plain).status_code == 403
    assert api.call("get", "/manage/users/9999/login-history", token=boss).status_code == 404


def test_login_events_cannot_be_changed_in_the_database(api, make_user):
    import pytest
    from django.db import DatabaseError

    api.login(make_user("a@corp.test").email)
    with pytest.raises(DatabaseError):
        LoginEvent.objects.update(success=False)


def test_revoke_others_keeps_only_the_current_session(api, make_user):
    user = make_user("a@corp.test")
    other = api.login(user.email, device="tablet")
    mine = api.login(user.email, device="phone")
    stranger = api.login(make_user("b@corp.test").email)
    done = api.call("post", "/me/sessions/revoke-others", token=mine["access"])
    assert done.status_code == 200 and done.data["revoked"] == 1
    assert api.call("get", "/me", token=other["access"]).status_code == 401
    assert api.call("get", "/me", token=mine["access"]).status_code == 200
    assert api.call("get", "/me", token=stranger["access"]).status_code == 200
    assert Session.objects.filter(user=user, revoked_at__isnull=True).count() == 1
    assert api.call("post", "/me/sessions/revoke-others", token=mine["access"]).data["revoked"] == 0
