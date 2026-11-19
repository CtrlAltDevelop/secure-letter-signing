from datetime import timedelta

import pytest
from django.utils import timezone

from accounts import guests
from accounts.models import Permission, User
from projects.tests.conftest import *  # noqa: F401,F403  (crew, project, ...)

from .conftest import PASSWORD

GUEST = {"email": "g@ext.test", "password": PASSWORD, "full_name": "Gina Guest"}


@pytest.fixture
def guest(crew):
    resp = crew.boss.call("post", "/manage/guests", GUEST)
    assert resp.status_code == 200, resp.content
    user = User.objects.get(pk=resp.data["id"])
    crew.guest = user
    crew.guest_d = type(crew.pam_d)(crew.pam_d.api, user)
    return crew


def put_access(crew, user, **body):
    return crew.boss.call("put", f"/manage/users/{user.id}/access", body)


def test_manager_creates_a_guest_without_default_grants(crew):
    resp = crew.boss.call("post", "/manage/guests", {**GUEST, "guest_expires_at": (timezone.now() + timedelta(days=3)).isoformat()})
    assert resp.status_code == 200 and resp.data["is_guest"] and resp.data["permissions"] == ["user"]
    assert resp.data["guest_expires_at"]
    assert crew.boss.call("post", "/manage/guests", GUEST).status_code == 409
    assert crew.boss.call("post", "/manage/guests", {**GUEST, "email": "x@e.test", "password": "123"}).status_code == 422
    assert crew.boss.call("post", "/manage/guests", {**GUEST, "email": "y@e.test", "guest_expires_at": "2020-01-01T00:00:00Z"}).status_code == 422
    assert crew.pam_d.call("post", "/manage/guests", {**GUEST, "email": "z@e.test"}).status_code == 403
    assert [u["email"] for u in crew.boss.call("get", "/manage/guests").data] == ["g@ext.test"]
    assert crew.pam_d.call("get", "/manage/guests").status_code == 403


def test_guest_cannot_hold_permissions(guest):
    crew = guest
    assert crew.boss.call("put", f"/manage/users/{crew.guest.id}/permissions", {"codes": ["task.create"]}).status_code == 422


def test_guest_invitation_signs_up_a_guest_with_expiry(crew, company):
    company.signup_invite_enabled = True
    company.save()
    exp = timezone.now() + timedelta(days=2)
    bad = crew.boss.call("post", "/manage/invites", {"guest": True, "codes": ["task.create"]})
    assert bad.status_code == 422
    inv = crew.boss.call("post", "/manage/invites", {"guest": True, "guest_expires_at": exp.isoformat()})
    assert inv.status_code == 200 and inv.data["guest"] is True
    signup = crew.pam_d.api.call("post", "/auth/signup", {"email": "inv@ext.test", "password": PASSWORD, "invite_code": inv.data["code"]})
    assert signup.status_code == 201
    user = User.objects.get(email="inv@ext.test")
    assert user.is_guest and user.guest_expires_at == exp and sorted(user.grants.values_list("code", flat=True)) == ["user"]


def test_guest_sees_only_tasks_projects_chat_modules(guest):
    crew = guest
    g = crew.guest_d
    for path in ("/letters", "/letters/directory", "/customers", "/meetings", "/notes", "/polls",
                 "/finance/docs", "/sales/leads", "/meeting-templates", "/poll-templates"):
        assert g.call("get", path).status_code == 404, path
    assert g.call("get", "/tasks").status_code == 200
    assert g.call("get", "/projects").status_code == 200
    assert g.call("get", "/me").data["is_guest"] is True
    assert crew.pam_d.call("get", "/notes").status_code == 200  # others are unaffected
    assert crew.pam_d.call("get", "/letters/directory").status_code == 200


def test_guest_sees_nothing_until_added_then_only_that_project(guest, project):
    crew = guest
    assert crew.guest_d.call("get", "/projects").data == []
    assert crew.guest_d.call("get", f"/projects/{project['id']}").status_code == 404
    out = put_access(crew, crew.guest, projects=[{"id": project["id"], "role": "member"}])
    assert out.status_code == 200 and out.data["projects"][0]["role"] == "member" and out.data["projects"][0]["active"]
    assert [p["id"] for p in crew.guest_d.call("get", "/projects").data] == [project["id"]]


def test_expired_guest_is_locked_out_and_extension_restores(guest):
    crew = guest
    User.objects.filter(pk=crew.guest.pk).update(guest_expires_at=timezone.now() - timedelta(minutes=1))
    assert crew.guest_d.call("get", "/me").status_code == 401
    assert crew.pam_d.api.call("post", "/auth/login", {"email": GUEST["email"], "password": PASSWORD}).status_code == 403
    later = (timezone.now() + timedelta(days=1)).isoformat()
    assert crew.boss.call("patch", f"/manage/guests/{crew.guest.id}", {"guest_expires_at": later}).status_code == 200
    assert crew.pam_d.api.call("post", "/auth/login", {"email": GUEST["email"], "password": PASSWORD}).status_code == 200
    assert crew.boss.call("patch", f"/manage/guests/{crew.guest.id}", {"clear_expiry": True}).data["guest_expires_at"] is None
    assert crew.boss.call("patch", f"/manage/guests/{crew.pam.id}", {"clear_expiry": True}).status_code == 404  # not a guest


def test_deactivating_a_guest_cuts_the_session(guest):
    crew = guest
    assert crew.boss.call("post", f"/manage/users/{crew.guest.id}/active", {"active": False}).status_code == 200
    assert crew.guest_d.call("get", "/me").status_code == 401


def test_guest_is_hidden_from_directory_and_rosters_unless_shared(guest, project):
    crew = guest
    emails = lambda: {u["email"] for u in crew.pam_d.call("get", "/letters/directory").data}  # noqa: E731
    assert GUEST["email"] not in emails()
    # a project manager cannot pull an unrelated guest into a project, nor mention them
    body = [{"user_id": crew.mia.id, "role": "member"}, {"user_id": crew.guest.id, "role": "member"}]
    assert crew.pam_d.call("put", f"/projects/{project['id']}/members", body).status_code == 422
    assert crew.pam_d.call("post", "/tasks", {"title": "t", "owner_ids": [crew.guest.id]}).status_code == 422
    # once the manager added the guest to the project they share it
    put_access(crew, crew.guest, projects=[{"id": project["id"]}])
    assert GUEST["email"] in emails()
    assert crew.out_d.call("get", "/letters/directory").data and GUEST["email"] not in {u["email"] for u in crew.out_d.call("get", "/letters/directory").data}


def test_guest_roster_helpers(guest, project):
    crew = guest
    assert set(guests.visible_users(crew.guest).values_list("pk", flat=True)) == {crew.guest.pk}
    put_access(crew, crew.guest, projects=[{"id": project["id"]}])
    seen = set(guests.visible_users(crew.guest).values_list("pk", flat=True))
    assert seen == {crew.guest.pk, crew.pam.pk, crew.mia.pk, crew.vic.pk, crew.mel.pk}
    assert guests.referable_ids(crew.guest, {crew.out.pk, crew.mia.pk}) == {crew.mia.pk}
    assert guests.referable_ids(crew.manager, {crew.out.pk, crew.guest.pk}) == {crew.out.pk, crew.guest.pk}


def test_guest_cannot_mention_strangers_and_not_be_a_customer_member(guest, project):
    crew = guest
    put_access(crew, crew.guest, projects=[{"id": project["id"], "role": "member"}])
    sid = crew.guest_d.call("get", f"/projects/{project['id']}").data["subject_id"]
    com = lambda who: crew.guest_d.call("post", f"/subjects/{sid}/comments", {"body": {"text": "hi"}, "mentions": [who.id]})  # noqa: E731
    assert com(crew.out).status_code == 422
    assert com(crew.mia).status_code in (200, 201)
    assert put_access(crew, crew.guest, customers=[{"id": "7b4d0b3c-0000-4000-8000-000000000000"}]).status_code == 422


def test_access_put_adds_deactivates_and_never_deletes(guest, project):
    from projects.models import ProjectMember

    crew = guest
    assert crew.pam_d.call("get", f"/manage/users/{crew.mia.id}/access").status_code == 403
    got = crew.boss.call("get", f"/manage/users/{crew.mia.id}/access").data
    assert [(p["id"], p["role"], p["active"]) for p in got["projects"]] == [(project["id"], "member", True)]
    out = put_access(crew, crew.mia, projects=[{"id": project["id"], "active": False}]).data
    assert out["projects"][0]["active"] is False
    assert crew.mia_d.call("get", f"/projects/{project['id']}").status_code == 404
    out = put_access(crew, crew.mia, projects=[{"id": project["id"], "role": "viewer"}]).data
    assert (out["projects"][0]["active"], out["projects"][0]["role"]) == (True, "viewer")
    assert ProjectMember.objects.filter(user=crew.mia).count() == 1
    assert put_access(crew, crew.mia, projects=[{"id": project["id"], "role": "boss"}]).status_code == 422
    # the owner cannot be removed or demoted
    assert put_access(crew, crew.pam, projects=[{"id": project["id"], "active": False}]).status_code == 422
    assert put_access(crew, crew.pam, projects=[{"id": project["id"], "role": "member"}]).status_code == 422
    assert put_access(crew, crew.pam, projects=[{"id": "7b4d0b3c-0000-4000-8000-000000000000"}]).status_code == 404
    assert crew.pam_d.call("put", f"/manage/users/{crew.mia.id}/access", {}).status_code == 403


def test_access_manages_chat_groups_and_customer_files(guest):
    from chat.models import Conversation, ConversationMember
    from crm.models import Customer, CustomerMember
    from workspace.models import Subject

    crew = guest
    conv = Conversation.objects.create(subject=Subject.objects.create(module="chat", kind="conversation"),
                                       kind="group", name="Ops", creator=crew.pam)
    ConversationMember.objects.create(conversation=conv, user=crew.pam, role="admin")
    out = put_access(crew, crew.mia, conversations=[{"id": str(conv.id)}]).data
    assert [(c["name"], c["role"], c["active"]) for c in out["conversations"]] == [("Ops", "member", True)]
    out = put_access(crew, crew.mia, conversations=[{"id": str(conv.id), "active": False}]).data
    assert out["conversations"][0]["active"] is False and ConversationMember.objects.filter(user=crew.mia).count() == 1
    dm = Conversation.objects.create(subject=Subject.objects.create(module="chat", kind="conversation"),
                                     kind="dm", creator=crew.pam, dm_key="1:2")
    assert put_access(crew, crew.mia, conversations=[{"id": str(dm.id)}]).status_code == 404
    cust = Customer.objects.create(subject=Subject.objects.create(module="crm", kind="customer"), name="Acme", owner=crew.pam)
    CustomerMember.objects.create(customer=cust, user=crew.pam, role="manager")
    out = put_access(crew, crew.mia, customers=[{"id": str(cust.id), "role": "viewer"}]).data
    assert out["customers"] == [{"id": str(cust.id), "role": "viewer", "active": True, "name": "", "kind": ""}]
    assert put_access(crew, crew.pam, customers=[{"id": str(cust.id), "active": False}]).status_code == 422
