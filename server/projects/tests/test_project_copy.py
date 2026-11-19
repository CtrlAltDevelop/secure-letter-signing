from accounts.models import AuditEvent
from projects.models import BoardColumn, Project
from projects.tests.conftest import column_id
from tasks.models import Task, TaskPerson
from workspace.models import Subject


def copy(who, project, name="Website v2"):
    return who.call("post", f"/projects/{project['id']}/copy", {"name": name})


def test_copy_clones_settings_columns_members_and_tasks(crew, project, make_ptask):
    crew.pam_d.call("patch", f"/projects/{project['id']}", {
        "members_can_extend": False, "require_removal_approval": True, "color": 7, "start_date": "2026-05-01"})
    crew.pam_d.call("post", f"/projects/{project['id']}/columns", {"title": "QA", "kind": "doing"})
    doing = column_id(project, "doing")
    a = make_ptask(title="A", checklist=["one", "two"], priority="high", weight=4, column_id=doing)
    b = make_ptask(title="B", owner_ids=[crew.mia.id, crew.mel.id], follower_ids=[crew.vic.id])
    crew.mia_d.call("patch", f"/tasks/{a['id']}", {"version": 1, "progress": 60})
    resp = copy(crew.pam_d, project)
    assert resp.status_code == 201, resp.content
    new = resp.data
    assert new["id"] != project["id"] and new["name"] == "Website v2" and new["status"] == "active"
    assert (new["color"], new["start_date"], new["members_can_extend"], new["require_removal_approval"]) == (
        7, "2026-05-01", False, True)
    assert new["owner"]["id"] == crew.pam.id and new["progress"] == 0
    assert new["description"] == {"text": "private plan"}
    roles = {m["user"]["id"]: m["role"] for m in new["members"]}
    assert roles == {crew.pam.id: "manager", crew.mia.id: "member", crew.vic.id: "viewer", crew.mel.id: "member"}
    assert [(c["title"], c["kind"], c["task_count"]) for c in new["columns"]] == [
        ("To do", "todo", 1), ("Doing", "doing", 1), ("Done", "done", 0), ("QA", "doing", 0)]
    copies = {t.title: t for t in Task.objects.filter(project_id=new["id"])}
    assert set(copies) == {"A", "B"}
    assert copies["A"].priority == "high" and copies["A"].weight == 4 and copies["A"].progress == 0
    assert copies["A"].status == "open" and str(copies["A"].copied_from_id) == a["id"]
    assert copies["A"].checklist.filter(done=False).count() == 2
    assert copies["A"].column.title == "Doing" and copies["B"].column.title == "To do"
    assert copies["A"].creator_id == crew.pam.id
    people = {(p.user_id, p.role) for p in TaskPerson.objects.filter(task=copies["B"], active=True)}
    assert people == {(crew.mia.id, "owner"), (crew.mel.id, "owner"), (crew.vic.id, "follower")}
    assert copies["A"].subject_id != a["subject_id"] and Subject.objects.filter(module="tasks").count() == 4
    assert Task.objects.filter(project_id=project["id"]).count() == 2  # the source is untouched


def test_copy_keeps_task_order_and_skips_removed_tasks(crew, project, make_ptask):
    first, second, gone = make_ptask(title="first"), make_ptask(title="second"), make_ptask(title="gone")
    Task.objects.filter(pk=gone["id"]).update(hidden=True)
    new = copy(crew.pam_d, project).data
    board = crew.pam_d.call("get", f"/projects/{new['id']}/tasks").data
    assert [t["title"] for t in board["columns"][0]["tasks"]] == ["first", "second"]
    assert first and second


def test_creator_becomes_manager_even_as_a_plain_member(crew, project):
    resp = copy(crew.mia_d, project)
    assert resp.status_code == 201
    assert resp.data["owner"]["id"] == crew.mia.id and resp.data["my_role"] == "manager"
    roles = {m["user"]["id"]: m["role"] for m in resp.data["members"]}
    assert roles[crew.mia.id] == "manager" and roles[crew.pam.id] == "manager"


def test_archived_source_can_be_copied(crew, project, make_ptask):
    make_ptask()
    crew.pam_d.call("patch", f"/projects/{project['id']}", {"status": "archived"})
    resp = copy(crew.pam_d, project)
    assert resp.status_code == 201 and resp.data["status"] == "active"
    assert Task.objects.filter(project_id=resp.data["id"]).count() == 1


def test_copy_permissions_and_validation(crew, project, make_user, login):
    assert copy(crew.out_d, project).status_code == 404
    assert copy(crew.boss, project).status_code == 404
    plain = make_user("plain@corp.test", grants=("task.create",))
    plain_d = login(plain)
    crew.pam_d.call("put", f"/projects/{project['id']}/members", [
        {"user_id": crew.pam.id, "role": "manager"}, {"user_id": plain.id, "role": "member"}])
    assert copy(plain_d, project).status_code == 403  # needs project.create
    assert copy(crew.pam_d, project, "  ").status_code == 422
    assert crew.pam_d.call("post", f"/projects/{project['id']}/copy", {}).status_code == 422
    assert Project.objects.count() == 1


def test_copy_audit_has_ids_only_and_group_follows_privacy(crew, project):
    mine = crew.mia_d.call("post", "/project-groups", {"name": "Mine", "scope": "personal"}).data
    crew.mia_d.call("patch", f"/projects/{project['id']}", {"group_id": mine["id"]})  # mia is not a manager: ignored
    pam_group = crew.pam_d.call("post", "/project-groups", {"name": "PamsFolder", "scope": "personal"}).data
    crew.pam_d.call("patch", f"/projects/{project['id']}", {"group_id": pam_group["id"]})
    new = copy(crew.mia_d, project, "Secret name").data
    assert new["group_id"] is None  # pam's personal folder does not follow mia
    assert all("Secret name" not in str(e.data) for e in AuditEvent.objects.filter(action="project_copied"))
    assert AuditEvent.objects.filter(action="project_copied").count() == 1
    assert BoardColumn.objects.filter(project_id=new["id"]).count() == 3
