from accounts.models import AuditEvent, OrgTitle


def tok(api, email):
    return api.login(email)["access"]


def test_titles_are_manager_only_and_deactivated_not_deleted(api, make_user, manager):
    make_user("a@corp.test")
    boss, plain = tok(api, manager.email), tok(api, "a@corp.test")
    for method, path, body in (("get", "/manage/titles", None), ("post", "/manage/titles", {"name": "Lead"}),
                               ("patch", "/manage/titles/1", {"active": False})):
        assert api.call(method, path, body, plain).status_code == 403
    made = api.call("post", "/manage/titles", {"name": " Team lead "}, boss)
    assert made.status_code == 201 and made.data["name"] == "Team lead" and made.data["members"] == 0
    assert api.call("post", "/manage/titles", {"name": "team LEAD"}, boss).status_code == 409
    assert api.call("post", "/manage/titles", {"name": "  "}, boss).status_code == 422
    tid = made.data["id"]
    renamed = api.call("patch", f"/manage/titles/{tid}", {"name": "Lead", "active": False}, boss)
    assert renamed.data["name"] == "Lead" and renamed.data["active"] is False
    assert [t["name"] for t in api.call("get", "/manage/titles", token=boss).data] == ["Lead"]
    assert OrgTitle.objects.count() == 1
    assert all("Lead" not in str(e.data) for e in AuditEvent.objects.all())


def test_assign_title_shows_in_profile_and_clears(api, make_user, manager):
    target = make_user("a@corp.test")
    boss, plain = tok(api, manager.email), tok(api, "a@corp.test")
    tid = api.call("post", "/manage/titles", {"name": "Analyst"}, boss).data["id"]
    assert api.call("put", f"/manage/users/{target.id}/title", {"title_id": tid}, plain).status_code == 403
    out = api.call("put", f"/manage/users/{target.id}/title", {"title_id": tid}, boss)
    assert out.status_code == 200 and out.data["title"] == "Analyst" and out.data["title_id"] == tid
    assert api.call("get", "/me", token=plain).data["title"] == "Analyst"
    assert api.call("get", "/manage/titles", token=boss).data[0]["members"] == 1
    cleared = api.call("put", f"/manage/users/{target.id}/title", {"title_id": None}, boss)
    assert cleared.data["title"] == "" and cleared.data["title_id"] is None


def test_assign_needs_an_active_existing_title(api, make_user, manager):
    target = make_user("a@corp.test")
    boss = tok(api, manager.email)
    tid = api.call("post", "/manage/titles", {"name": "Old"}, boss).data["id"]
    api.call("patch", f"/manage/titles/{tid}", {"active": False}, boss)
    assert api.call("put", f"/manage/users/{target.id}/title", {"title_id": tid}, boss).status_code == 404
    assert api.call("put", f"/manage/users/{target.id}/title", {"title_id": 999}, boss).status_code == 404


def test_status_text_profile_and_limit(api, make_user):
    make_user("a@corp.test")
    token = tok(api, "a@corp.test")
    resp = api.call("patch", "/me", {"status_text": "  In a meeting  "}, token)
    assert resp.data["status_text"] == "In a meeting"
    assert api.call("patch", "/me", {"status_text": "x" * 81}, token).status_code == 422
    assert api.call("patch", "/me", {"status_text": ""}, token).data["status_text"] == ""


def test_legacy_title_shows_until_a_company_title_is_set(api, make_user, manager):
    target = make_user("a@corp.test")
    token = tok(api, "a@corp.test")
    assert api.call("patch", "/me", {"title": "Intern"}, token).data["title"] == "Intern"
    boss = tok(api, manager.email)
    tid = api.call("post", "/manage/titles", {"name": "Dev"}, boss).data["id"]
    api.call("put", f"/manage/users/{target.id}/title", {"title_id": tid}, boss)
    assert api.call("get", "/me", token=token).data["title"] == "Dev"
