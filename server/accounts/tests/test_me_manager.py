from accounts.models import AuditEvent, CompanySettings, InviteCode, Session


def token_for(api, email):
    return api.login(email)["access"]


# --- me ---------------------------------------------------------------------------------------

def test_profile_update(api, make_user):
    make_user("a@corp.test")
    token = token_for(api, "a@corp.test")
    resp = api.call("patch", "/me", {"full_name": "Ada", "department": "R&D"}, token)
    assert resp.data["full_name"] == "Ada" and resp.data["department"] == "R&D"


def test_sessions_list_marks_current_and_can_revoke_another(api, make_user):
    make_user("a@corp.test")
    phone = api.login("a@corp.test", device="phone")
    laptop = api.login("a@corp.test", device="laptop")
    rows = api.call("get", "/me/sessions", token=phone["access"]).data
    assert {r["device_name"]: r["current"] for r in rows} == {"phone": True, "laptop": False}
    assert api.call("post", f"/me/sessions/{laptop['session_id']}/revoke", token=phone["access"]).status_code == 200
    assert api.call("get", "/me", token=laptop["access"]).status_code == 401
    assert api.call("get", "/me", token=phone["access"]).status_code == 200


def test_cannot_revoke_someone_elses_session(api, make_user):
    make_user("a@corp.test")
    make_user("b@corp.test")
    other = api.login("b@corp.test")
    mine = token_for(api, "a@corp.test")
    assert api.call("post", f"/me/sessions/{other['session_id']}/revoke", token=mine).status_code == 404


def test_password_change_keeps_this_session_and_drops_others(api, make_user):
    make_user("a@corp.test")
    here = api.login("a@corp.test")
    there = api.login("a@corp.test")
    from .conftest import PASSWORD

    resp = api.call("post", "/me/password", {"current_password": PASSWORD, "new_password": "N3w-Str0ng-Pass!!"}, here["access"])
    assert resp.status_code == 200
    assert api.call("get", "/me", token=here["access"]).status_code == 200
    assert api.call("get", "/me", token=there["access"]).status_code == 401


# --- manager ----------------------------------------------------------------------------------

def test_manage_endpoints_are_manager_only(api, make_user):
    make_user("a@corp.test")
    token = token_for(api, "a@corp.test")
    for path in ("/manage/users", "/manage/permissions", "/manage/company", "/manage/invites"):
        assert api.call("get", path, token=token).status_code == 403


def test_manager_sets_permissions_and_base_is_kept(api, manager, make_user):
    target = make_user("a@corp.test")
    token = token_for(api, manager.email)
    resp = api.call("put", f"/manage/users/{target.id}/permissions", {"codes": ["letter.create", "letter.sign"]}, token)
    assert resp.data["permissions"] == ["letter.create", "letter.sign", "user"]
    assert AuditEvent.objects.filter(action="permissions_set", target="a@corp.test").exists()
    cleared = api.call("put", f"/manage/users/{target.id}/permissions", {"codes": []}, token)
    assert cleared.data["permissions"] == ["user"]


def test_unknown_permission_code_is_rejected(api, manager, make_user):
    target = make_user("a@corp.test")
    resp = api.call("put", f"/manage/users/{target.id}/permissions", {"codes": ["letter.destroy"]}, token_for(api, manager.email))
    assert resp.status_code == 422


def test_deactivate_revokes_sessions_and_blocks_login(api, manager, make_user):
    target = make_user("a@corp.test")
    victim = api.login("a@corp.test")
    token = token_for(api, manager.email)
    assert api.call("post", f"/manage/users/{target.id}/active", {"active": False}, token).status_code == 200
    assert api.call("get", "/me", token=victim["access"]).status_code == 401
    assert Session.objects.filter(user=target, revoked_at__isnull=True).count() == 0
    assert api.call("post", "/auth/login", {"email": "a@corp.test", "password": "x"}).status_code == 401


def test_manager_cannot_deactivate_self_or_superuser(api, manager, make_user):
    from accounts.models import User

    root = User.objects.create_superuser("root@corp.test", "x-Str0ng-Passw0rd!")
    token = token_for(api, manager.email)
    assert api.call("post", f"/manage/users/{manager.id}/active", {"active": False}, token).status_code == 403
    assert api.call("post", f"/manage/users/{root.id}/active", {"active": False}, token).status_code == 403


def test_company_settings_toggle_and_normalize_domain(api, manager):
    token = token_for(api, manager.email)
    resp = api.call("patch", "/manage/company", {"signup_domain_enabled": True, "allowed_domain": "@Corp.TEST "}, token)
    assert resp.data["allowed_domain"] == "corp.test" and resp.data["signup_domain_enabled"] is True
    assert CompanySettings.load().signup_domain_enabled is True


def test_invites_create_list_deactivate(api, manager):
    token = token_for(api, manager.email)
    created = api.call("post", "/manage/invites", {"max_uses": 3}, token).data
    assert created["max_uses"] == 3 and created["active"] is True
    assert [i["id"] for i in api.call("get", "/manage/invites", token=token).data] == [created["id"]]
    off = api.call("post", f"/manage/invites/{created['id']}/deactivate", token=token).data
    assert off["active"] is False
    assert InviteCode.objects.get(pk=created["id"]).active is False
    assert api.call("post", "/manage/invites", {"max_uses": 0}, token).status_code == 422


def test_manager_issues_reset_token_when_email_is_unavailable(api, manager, make_user):
    target = make_user("a@corp.test")
    token = token_for(api, manager.email)
    reset = api.call("post", f"/manage/users/{target.id}/reset-token", token=token).data["token"]
    resp = api.call("post", "/auth/password-reset/confirm", {"token": reset, "new_password": "Fr3sh-Str0ng-Pass!!"})
    assert resp.status_code == 200


def test_manager_cannot_touch_superuser_permissions_or_reset_token(api, manager, make_user):
    root = make_user("root@corp.test")
    root.is_superuser = True
    root.save(update_fields=["is_superuser"])
    token = api.login(manager.email)["access"]
    assert api.call("put", f"/manage/users/{root.id}/permissions", {"codes": ["user"]}, token=token).status_code == 403
    assert api.call("post", f"/manage/users/{root.id}/reset-token", token=token).status_code == 403
