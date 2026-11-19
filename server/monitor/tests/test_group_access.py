import pytest

from accounts.models import AuditEvent
from projects.models import ProjectMember


@pytest.fixture
def grouped(crew, project):
    gid = crew.boss.call("post", "/project-groups", {"name": "Ops", "scope": "org"}).data["id"]
    assert crew.pam_d.call("patch", f"/projects/{project['id']}", {"group_id": gid}).status_code == 200
    return gid


def role_of(project, user):
    row = ProjectMember.objects.filter(project_id=project["id"], user=user, active=True).first()
    return row.role if row else None


def test_manager_adds_and_deactivates_group_access(crew, project, grouped):
    body = {"add": [{"user_id": crew.out.id, "role": "member"}], "remove": [crew.vic.id]}
    resp = crew.boss.call("put", f"/project-groups/{grouped}/access", body)
    assert resp.status_code == 200 and resp.data["projects_changed"] == 1
    assert role_of(project, crew.out) == "member" and role_of(project, crew.vic) is None
    assert ProjectMember.objects.filter(project_id=project["id"], user=crew.vic, active=False).count() == 1


def test_owner_cannot_be_removed_by_group_access(crew, project, grouped):
    crew.boss.call("put", f"/project-groups/{grouped}/access", {"remove": [crew.pam.id]})
    assert role_of(project, crew.pam) == "manager"


def test_group_access_is_manager_only(crew, grouped):
    assert crew.pam_d.call("put", f"/project-groups/{grouped}/access", {}).status_code == 403


def test_group_access_rejects_overlap_and_unknown_user(crew, grouped):
    overlap = {"add": [{"user_id": crew.out.id, "role": "member"}], "remove": [crew.out.id]}
    assert crew.boss.call("put", f"/project-groups/{grouped}/access", overlap).status_code == 422
    unknown = {"add": [{"user_id": 99999, "role": "member"}]}
    assert crew.boss.call("put", f"/project-groups/{grouped}/access", unknown).status_code == 422


def test_group_access_audit_has_ids_only(crew, grouped):
    crew.boss.call("put", f"/project-groups/{grouped}/access", {"add": [{"user_id": crew.out.id, "role": "viewer"}]})
    event = AuditEvent.objects.filter(action="project_group_access_changed").get()
    assert set(event.data) == {"added", "removed", "projects"}
