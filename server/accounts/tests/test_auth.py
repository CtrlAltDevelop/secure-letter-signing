from datetime import timedelta

import pytest
from django.core import mail
from django.db import IntegrityError, transaction
from django.utils import timezone

from accounts.models import InviteCode, Session, User

from .conftest import PASSWORD


def test_login_returns_tokens_and_user(api, make_user):
    make_user("a@corp.test")
    body = api.login("a@corp.test")
    assert body["user"]["permissions"] == ["user"]
    assert api.call("get", "/me", token=body["access"]).data["email"] == "a@corp.test"


def test_login_rejects_wrong_password_and_inactive(api, make_user):
    make_user("a@corp.test")
    make_user("off@corp.test", active=False)
    assert api.call("post", "/auth/login", {"email": "a@corp.test", "password": "nope"}).status_code == 401
    assert api.call("post", "/auth/login", {"email": "off@corp.test", "password": PASSWORD}).status_code == 401


def test_protected_endpoint_needs_a_valid_token(api):
    assert api.call("get", "/me").status_code == 401
    assert api.call("get", "/me", token="garbage").status_code == 401


def test_revoked_session_is_rejected_immediately(api, make_user):
    make_user("a@corp.test")
    body = api.login("a@corp.test")
    Session.objects.update(revoked_at=timezone.now())
    assert api.call("get", "/me", token=body["access"]).status_code == 401


def test_refresh_rotates_and_reuse_kills_the_session(api, make_user):
    make_user("a@corp.test")
    first = api.login("a@corp.test")
    second = api.call("post", "/auth/refresh", {"refresh": first["refresh"]})
    assert second.status_code == 200 and second.data["refresh"] != first["refresh"]
    # replaying the old token is treated as theft
    assert api.call("post", "/auth/refresh", {"refresh": first["refresh"]}).status_code == 401
    assert api.call("get", "/me", token=second.data["access"]).status_code == 401


def test_logout_revokes_the_session(api, make_user):
    make_user("a@corp.test")
    body = api.login("a@corp.test")
    assert api.call("post", "/auth/logout", token=body["access"]).status_code == 200
    assert api.call("get", "/me", token=body["access"]).status_code == 401


def test_signup_is_closed_by_default(api, db):
    resp = api.call("post", "/auth/signup", {"email": "x@corp.test", "password": PASSWORD})
    assert resp.status_code == 403


def test_invite_signup_works_once_for_any_email(api, manager, company):
    company.signup_invite_enabled = True
    company.save()
    invite = InviteCode.objects.create(created_by=manager, max_uses=1)
    ok = api.call("post", "/auth/signup", {"email": "n@gmail.test", "password": PASSWORD, "invite_code": invite.code})
    assert ok.status_code == 201
    assert api.login("n@gmail.test")["user"]["permissions"] == ["user"]
    again = api.call("post", "/auth/signup", {"email": "m@gmail.test", "password": PASSWORD, "invite_code": invite.code})
    assert again.status_code == 403


def test_expired_or_inactive_invite_is_refused(api, manager, company):
    company.signup_invite_enabled = True
    company.save()
    expired = InviteCode.objects.create(created_by=manager, expires_at=timezone.now() - timedelta(days=1))
    off = InviteCode.objects.create(created_by=manager, active=False)
    for code in (expired.code, off.code):
        resp = api.call("post", "/auth/signup", {"email": "n@x.test", "password": PASSWORD, "invite_code": code})
        assert resp.status_code == 403


def test_domain_signup_needs_email_verification(api, company):
    company.signup_domain_enabled = True
    company.allowed_domain = "corp.test"
    company.save()
    resp = api.call("post", "/auth/signup", {"email": "Eve@Corp.test", "password": PASSWORD})
    assert resp.status_code == 202
    assert api.call("post", "/auth/login", {"email": "eve@corp.test", "password": PASSWORD}).status_code == 401
    token = mail.outbox[0].body.strip().splitlines()[-1]
    assert api.call("post", "/auth/verify-email", {"token": token}).status_code == 200
    assert api.login("eve@corp.test")["user"]["email"] == "eve@corp.test"


def test_domain_signup_rejects_other_domains(api, company):
    company.signup_domain_enabled = True
    company.allowed_domain = "corp.test"
    company.save()
    assert api.call("post", "/auth/signup", {"email": "x@evil.test", "password": PASSWORD}).status_code == 403


def test_domain_signup_without_email_setup_is_unavailable(api, company, settings):
    settings.EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
    company.signup_domain_enabled = True
    company.allowed_domain = "corp.test"
    company.save()
    resp = api.call("post", "/auth/signup", {"email": "x@corp.test", "password": PASSWORD})
    assert resp.status_code == 503
    assert not User.objects.filter(email="x@corp.test").exists()


def test_weak_password_and_duplicate_email_are_rejected(api, manager, company):
    company.signup_invite_enabled = True
    company.save()
    invite = InviteCode.objects.create(created_by=manager, max_uses=5)
    weak = api.call("post", "/auth/signup", {"email": "w@x.test", "password": "12345678", "invite_code": invite.code})
    assert weak.status_code == 422
    dup = api.call("post", "/auth/signup", {"email": manager.email, "password": PASSWORD, "invite_code": invite.code})
    assert dup.status_code == 409


def test_password_reset_is_single_use_and_revokes_sessions(api, make_user):
    make_user("a@corp.test")
    body = api.login("a@corp.test")
    api.call("post", "/auth/password-reset/request", {"email": "a@corp.test"})
    token = mail.outbox[0].body.strip().splitlines()[-1]
    new_password = "An0ther-Str0ng-Pass!"
    assert api.call("post", "/auth/password-reset/confirm", {"token": token, "new_password": new_password}).status_code == 200
    assert api.call("get", "/me", token=body["access"]).status_code == 401
    assert api.login("a@corp.test", new_password)
    assert api.call("post", "/auth/password-reset/confirm", {"token": token, "new_password": new_password}).status_code == 400


def test_password_reset_request_does_not_reveal_unknown_emails(api, db):
    resp = api.call("post", "/auth/password-reset/request", {"email": "ghost@corp.test"})
    assert resp.status_code == 200 and mail.outbox == []


def test_only_one_manager_can_exist(make_user):
    make_user("m1@corp.test", manager=True)
    with pytest.raises(IntegrityError), transaction.atomic():
        make_user("m2@corp.test", manager=True)


def test_login_is_throttled(api, make_user):
    make_user("a@corp.test")
    codes = {api.call("post", "/auth/login", {"email": "a@corp.test", "password": "bad"}).status_code for _ in range(25)}
    assert 429 in codes
