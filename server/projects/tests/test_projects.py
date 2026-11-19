import json

import pytest

from accounts.models import AuditEvent, Notification
from projects.models import BoardColumn, Project, ProjectMember
from workspace.models import ChangeHistory, Event
from projects.tests.conftest import column_id


def url(project, tail=""):
    return f"/projects/{project['id']}{tail}"


def test_create_gives_default_columns_and_owner_manager(crew, project):
    assert [(c["title"], c["kind"]) for c in project["columns"]] == [
        ("To do", "todo"), ("Doing", "doing"), ("Done", "done")]
    ranks = [c["rank"] for c in project["columns"]]
    assert ranks == sorted(ranks) and all(c["task_count"] == 0 for c in project["columns"])
    roles = {m["user"]["id"]: m["role"] for m in project["members"]}
    assert roles == {crew.pam.id: "manager", crew.mia.id: "member", crew.vic.id: "viewer", crew.mel.id: "member"}
    assert project["my_role"] == "manager" and project["owner"]["id"] == crew.pam.id and project["progress"] == 0
    assert project["description"] == {"text": "private plan"}
    assert project["can"] == {"see": True, "comment": True, "label": True, "edit": True, "moderate": True,
                              "create_task": True}


def test_description_encrypted_name_plain_and_audit_has_no_name(project):
    row = Project.objects.get(pk=project["id"])
    assert row.description["v"] == 3 and "private plan" not in json.dumps(row.description)
    assert row.name == "Website" and row.subject.module == "projects" and row.subject.kind == "project"
    assert all("Website" not in json.dumps(e.data) for e in AuditEvent.objects.all())


def test_create_needs_project_create_grant(make_user, login):
    plain = login(make_user("plain@corp.test", grants=("task.create",)))
    assert plain.call("post", "/projects", {"name": "x"}).status_code == 403


def test_create_validation(crew):
    assert crew.pam_d.call("post", "/projects", {"name": "x", "members": [{"user_id": 99999, "role": "member"}]}
                           ).status_code == 422
    assert crew.pam_d.call("post", "/projects", {"name": "x", "start_date": "2026-05-02", "end_date": "2026-05-01"}
                           ).status_code == 422
    assert crew.pam_d.call("post", "/projects", {"name": "x", "group_id": 999}).status_code == 422


def test_permission_matrix(crew, project):
    expected = {  # who -> (get, patch, put members, add column)
        "pam": (200, 200, 200, 201), "mia": (200, 403, 403, 403), "vic": (200, 403, 403, 403),
        "out": (404, 404, 404, 404), "boss": (404, 404, 404, 404)}
    members = [{"user_id": crew.pam.id, "role": "manager"}, {"user_id": crew.mia.id, "role": "member"},
               {"user_id": crew.vic.id, "role": "viewer"}, {"user_id": crew.mel.id, "role": "member"}]
    for name, (get, patch, put, col) in expected.items():
        who = getattr(crew, f"{name}_d") if name != "boss" else crew.boss
        assert who.call("get", url(project)).status_code == get, name
        assert who.call("patch", url(project), {"color": 3}).status_code == patch, name
        assert who.call("put", url(project, "/members"), members).status_code == put, name
        assert who.call("post", url(project, "/columns"), {"title": "QA"}).status_code == col, name


def test_list_only_my_projects_with_filters(crew, project):
    assert [p["id"] for p in crew.mia_d.call("get", "/projects").data] == [project["id"]]
    assert crew.out_d.call("get", "/projects").data == [] and crew.boss.call("get", "/projects").data == []
    assert crew.mia_d.call("get", "/projects?q=web").data and not crew.mia_d.call("get", "/projects?q=zzz").data
    assert not crew.mia_d.call("get", "/projects?status=archived").data
    crew.pam_d.call("patch", url(project), {"status": "archived"})
    assert crew.mia_d.call("get", "/projects?status=archived").data[0]["my_role"] == "member"


def test_patch_writes_history_and_event_without_plain_secrets(crew, project):
    resp = crew.pam_d.call("patch", url(project), {"name": "Site", "description": {"text": "new"}, "color": 4,
                                                    "start_date": "2026-05-01"})
    assert resp.status_code == 200 and resp.data["name"] == "Site"
    rows = {h.field: h for h in ChangeHistory.objects.filter(subject_id=project["subject_id"])}
    assert rows["name"].old == "Website" and rows["name"].new == "Site"
    assert rows["description"].new == {"changed": True} and rows["description"].old is None
    ev = Event.objects.filter(kind="project.updated").latest("id")
    assert ev.title == "Site" and set(ev.data["fields"]) == {"name", "description", "color", "start_date"}
    assert crew.pam.id not in set(ev.recipients.values_list("user_id", flat=True))
    assert crew.mia.id in set(ev.recipients.values_list("user_id", flat=True))


def test_members_replace_owner_stays_and_removed_lose_access(crew, project):
    new = [{"user_id": crew.pam.id, "role": "manager"}, {"user_id": crew.mia.id, "role": "viewer"},
           {"user_id": crew.out.id, "role": "member"}]
    resp = crew.pam_d.call("put", url(project, "/members"), new)
    assert resp.status_code == 200
    assert {m["user"]["id"]: m["role"] for m in resp.data["members"]} == {
        crew.pam.id: "manager", crew.mia.id: "viewer", crew.out.id: "member"}
    assert crew.vic_d.call("get", url(project)).status_code == 404
    assert crew.out_d.call("get", url(project)).status_code == 200
    assert ProjectMember.objects.get(project_id=project["id"], user=crew.vic).active is False  # kept
    note = Notification.objects.get(user=crew.out, kind="project.member_added")
    assert note.title == "Website" and note.data["module"] == "projects"
    ev = Event.objects.get(kind="project.member.added")
    assert ev.data["user_ids"] == [crew.out.id]
    assert not Notification.objects.filter(user=crew.mia, kind="project.member_added").exclude(
        pk__in=Notification.objects.filter(user=crew.mia, data__object_id=project["id"])).exists()


def test_owner_cannot_be_removed_or_demoted_and_lists_are_validated(crew, project):
    assert crew.pam_d.call("put", url(project, "/members"), [{"user_id": crew.mia.id, "role": "manager"}]
                           ).status_code == 422
    assert crew.pam_d.call("put", url(project, "/members"), [{"user_id": crew.pam.id, "role": "member"}]
                           ).status_code == 422
    dup = [{"user_id": crew.pam.id, "role": "manager"}, {"user_id": crew.mia.id, "role": "member"},
           {"user_id": crew.mia.id, "role": "viewer"}]
    assert crew.pam_d.call("put", url(project, "/members"), dup).status_code == 422
    assert crew.pam_d.call("put", url(project, "/members"), [{"user_id": crew.pam.id, "role": "boss"}]
                           ).status_code == 422


def test_second_manager_can_edit_and_demoted_member_cannot(crew, project):
    members = [{"user_id": crew.pam.id, "role": "manager"}, {"user_id": crew.mia.id, "role": "manager"}]
    assert crew.pam_d.call("put", url(project, "/members"), members).status_code == 200
    assert crew.mia_d.call("patch", url(project), {"color": 9}).status_code == 200
    assert crew.mia_d.call("put", url(project, "/members"), members[:1]).status_code == 200
    assert crew.mia_d.call("patch", url(project), {"color": 1}).status_code == 404  # removed: no access


def test_columns_add_rename_reorder_hide(crew, project, make_ptask):
    pam = crew.pam_d
    cols = pam.call("post", url(project, "/columns"), {"title": "QA", "kind": "doing"}).data
    assert [c["title"] for c in cols][-1] == "QA"
    qa = cols[-1]["id"]
    assert pam.call("patch", url(project, f"/columns/{qa}"), {"title": "Review"}).data[-1]["title"] == "Review"
    order = [c["id"] for c in cols][::-1]
    assert [c["id"] for c in pam.call("put", url(project, "/columns/order"), {"ids": order}).data] == order
    assert pam.call("put", url(project, "/columns/order"), {"ids": order[:-1]}).status_code == 422
    assert [c["id"] for c in crew.mia_d.call("get", url(project, "/columns")).data] == order
    todo = column_id(project, "todo")
    make_ptask()
    assert pam.call("patch", url(project, f"/columns/{todo}"), {"active": False}).status_code == 409
    assert pam.call("patch", url(project, f"/columns/{qa}"), {"active": False}).status_code == 200
    assert BoardColumn.objects.get(pk=qa).active is False
    assert pam.call("patch", url(project, "/columns/999999"), {"title": "x"}).status_code == 404


def test_database_refuses_deleting_projects(project):
    from django.db import transaction
    from django.db.utils import DatabaseError

    for model in (Project, ProjectMember, BoardColumn):
        with pytest.raises(DatabaseError), transaction.atomic():
            model.objects.all()._raw_delete(model.objects.db)


def test_module_off_is_404(crew, project, brand_dir):
    brand_dir(modules=["letters", "tasks"])
    assert crew.pam_d.call("get", "/projects").status_code == 404
    assert crew.pam_d.call("get", url(project)).status_code == 404
    assert crew.pam_d.call("post", "/projects", {"name": "x"}).status_code == 404
    assert crew.pam_d.call("get", "/project-groups").status_code == 404
    body = {"title": "t", "project_id": project["id"]}
    assert crew.pam_d.call("post", "/tasks", body).status_code == 404
    assert crew.pam_d.call("post", f"/subjects/{project['subject_id']}/comments", {"body": {"text": "x"}}
                           ).status_code == 404


def test_project_as_subject_comments_and_labels(crew, project):
    path = f"/subjects/{project['subject_id']}"
    assert crew.vic_d.call("post", f"{path}/comments", {"body": {"text": "viewer says hi"}}).status_code == 201
    assert crew.out_d.call("get", f"{path}/comments").status_code == 404
    assert crew.vic_d.call("post", f"{path}/comments", {"body": {"text": "r"}, "kind": "report"}).status_code == 422
    assert crew.vic_d.call("put", f"{path}/labels", {"label_ids": []}).status_code == 403  # viewers cannot label
    assert crew.mia_d.call("put", f"{path}/labels", {"label_ids": []}).status_code == 200
    ev = Event.objects.get(kind="comment.created")
    assert ev.title == "Website" and crew.mia.id in set(ev.recipients.values_list("user_id", flat=True))
    assert crew.mia_d.call("delete", f"/comments/{Event.objects.get(kind='comment.created').data['comment_id']}"
                           ).status_code == 403  # only a manager may moderate others' comments
    assert crew.pam_d.call("delete", f"/comments/{ev.data['comment_id']}").status_code == 204


def test_groups_org_manager_only_personal_private(crew, project):
    assert crew.pam_d.call("post", "/project-groups", {"name": "Org", "scope": "org"}).status_code == 403
    org = crew.boss.call("post", "/project-groups", {"name": "Org", "scope": "org"})
    mine = crew.pam_d.call("post", "/project-groups", {"name": "Mine", "scope": "personal"})
    assert org.status_code == 201 and mine.data["scope"] == "personal"
    assert [g["name"] for g in crew.mia_d.call("get", "/project-groups").data] == ["Org"]
    assert [g["name"] for g in crew.pam_d.call("get", "/project-groups").data] == ["Org", "Mine"]
    assert crew.mia_d.call("patch", f"/project-groups/{mine.data['id']}", {"name": "x"}).status_code == 404
    assert crew.mia_d.call("patch", f"/project-groups/{org.data['id']}", {"name": "x"}).status_code == 403
    assert crew.boss.call("patch", f"/project-groups/{org.data['id']}", {"name": "Company"}).data["name"] == "Company"
    # group on a project: org group visible to all, personal one only to its owner
    assert crew.pam_d.call("patch", url(project), {"group_id": mine.data["id"]}).data["group_id"] == mine.data["id"]
    assert crew.mia_d.call("get", url(project)).data["group_id"] is None
    assert crew.pam_d.call("get", f"/projects?group={mine.data['id']}").data[0]["id"] == project["id"]
    assert crew.pam_d.call("patch", url(project), {"group_id": org.data["id"]}).data["group_id"] == org.data["id"]
    assert crew.mia_d.call("get", url(project)).data["group_id"] == org.data["id"]
    assert crew.mia_d.call("patch", url(project), {"group_id": mine.data["id"]}).status_code == 403
    assert crew.pam_d.call("patch", url(project), {"group_id": None}).data["group_id"] is None


def test_group_deactivate_hides_it_and_blocks_new_use(crew, project):
    org = crew.boss.call("post", "/project-groups", {"name": "Org", "scope": "org"}).data
    assert crew.boss.call("patch", f"/project-groups/{org['id']}", {"active": False}).data["active"] is False
    assert crew.mia_d.call("get", "/project-groups").data == []
    assert [g["id"] for g in crew.boss.call("get", "/project-groups?include_inactive=true").data] == [org["id"]]
    assert crew.pam_d.call("patch", url(project), {"group_id": org["id"]}).status_code == 422
