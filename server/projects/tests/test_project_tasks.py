import hashlib
from datetime import datetime, timedelta, timezone

from accounts.models import AuditEvent, Permission
from core import filestore
from projects.models import BoardColumn, Project
from projects.tests.conftest import column_id
from tasks.models import Task
from workspace.models import ChangeHistory, Comment, Event, File, Label, SubjectLabel
from workspace.models import Subject


def tpath(task, tail=""):
    return f"/tasks/{task['id']}{tail}"


def ppath(project, tail=""):
    return f"/projects/{project['id']}{tail}"


def board(who, project, **params):
    query = "&".join(f"{k}={v}" for k, v in params.items())
    return who.call("get", ppath(project, f"/tasks?view=board&{query}")).data


def ids_in(col):
    return [t["id"] for t in col["tasks"]]


# --- create / visibility ----------------------------------------------------------------------------------------


def test_create_in_project_matrix(crew, project):
    body = {"title": "T", "project_id": project["id"], "owner_ids": [crew.mia.id]}
    assert crew.vic_d.call("post", "/tasks", body).status_code == 403  # viewer
    assert crew.out_d.call("post", "/tasks", body).status_code == 404  # outsider
    crew.manager.grants.add(Permission.objects.get(code="task.create"))
    assert crew.boss.call("post", "/tasks", body).status_code == 404  # company manager: no automatic access
    assert crew.pam_d.call("post", "/tasks", body).status_code == 201
    made = crew.mia_d.call("post", "/tasks", body)
    assert made.status_code == 201 and made.data["project_id"] == project["id"]
    assert made.data["column_id"] == column_id(project, "todo")


def test_create_needs_task_create_grant_even_for_members(crew, project):
    crew.mia.grants.remove(Permission.objects.get(code="task.create"))
    body = {"title": "T", "project_id": project["id"], "owner_ids": [crew.mia.id]}
    assert crew.mia_d.call("post", "/tasks", body).status_code == 403


def test_people_must_be_project_members(crew, project):
    body = {"title": "T", "project_id": project["id"], "owner_ids": [crew.out.id]}
    assert crew.mia_d.call("post", "/tasks", body).status_code == 422
    task = crew.mia_d.call("post", "/tasks", {**body, "owner_ids": [crew.mia.id]}).data
    resp = crew.mia_d.call("put", tpath(task, "/people"), {"owner_ids": [crew.mia.id], "follower_ids": [crew.out.id]})
    assert resp.status_code == 422  # the creator may edit people, but a non-member could never see the task
    ok = crew.mia_d.call("put", tpath(task, "/people"), {"owner_ids": [crew.mia.id], "follower_ids": [crew.mel.id]})
    assert ok.status_code == 200


# --- ranks --------------------------------------------------------------------------------------------------------


def test_new_tasks_get_gapped_increasing_ranks(project, make_ptask):
    tasks = [make_ptask(title=f"t{i}") for i in range(3)]
    assert [t["rank"] for t in tasks] == [65_536, 131_072, 196_608]


def test_move_before_reorders_within_a_column(crew, project, make_ptask):
    a, b, c = (make_ptask(title=n) for n in "abc")
    todo = column_id(project, "todo")
    resp = crew.pam_d.call("post", tpath(c, "/move"), {"project_id": project["id"], "column_id": todo,
                                                         "before_id": a["id"]})
    assert resp.status_code == 200 and 0 < resp.data["rank"] < a["rank"]
    cols = board(crew.pam_d, project)["columns"]
    assert ids_in(cols[0]) == [c["id"], a["id"], b["id"]]
    crew.pam_d.call("post", tpath(a, "/move"), {"project_id": project["id"], "column_id": todo, "before_id": b["id"]})
    crew.pam_d.call("post", tpath(a, "/move"), {"project_id": project["id"], "column_id": todo})  # to the end
    assert ids_in(board(crew.pam_d, project)["columns"][0]) == [c["id"], b["id"], a["id"]]


def test_renumbering_when_no_room(crew, project, make_ptask):
    a, b, c = (make_ptask(title=n) for n in "abc")
    Task.objects.filter(pk=a["id"]).update(rank=10)
    Task.objects.filter(pk=b["id"]).update(rank=11)  # no integer between a and b
    todo = column_id(project, "todo")
    resp = crew.pam_d.call("post", tpath(c, "/move"), {"project_id": project["id"], "column_id": todo,
                                                         "before_id": b["id"]})
    assert resp.status_code == 200
    rows = list(Task.objects.filter(column_id=todo).order_by("rank", "id"))
    assert [str(t.id) for t in rows] == [a["id"], c["id"], b["id"]]
    assert [t.rank for t in rows] == [65_536, 131_072, 196_608]


def test_move_to_front_when_first_rank_is_tiny_renumbers(crew, project, make_ptask):
    a, b = make_ptask(title="a"), make_ptask(title="b")
    Task.objects.filter(pk=a["id"]).update(rank=1)
    todo = column_id(project, "todo")
    crew.pam_d.call("post", tpath(b, "/move"), {"project_id": project["id"], "column_id": todo, "before_id": a["id"]})
    assert ids_in(board(crew.pam_d, project)["columns"][0]) == [b["id"], a["id"]]
    assert all(t.rank > 0 for t in Task.objects.filter(column_id=todo))


# --- move rules ---------------------------------------------------------------------------------------------------


def test_move_between_columns_does_not_complete(crew, project, make_ptask):
    task = make_ptask()
    done = column_id(project, "done")
    resp = crew.pam_d.call("post", tpath(task, "/move"), {"project_id": project["id"], "column_id": done})
    assert resp.status_code == 200 and resp.data["column_id"] == done and resp.data["status"] == "open"
    assert resp.data["version"] == task["version"] + 1
    cols = {c["kind"]: c for c in board(crew.mel_d, project)["columns"]}
    assert ids_in(cols["done"]) == [task["id"]] and cols["todo"]["tasks"] == []
    fields = set(ChangeHistory.objects.filter(subject_id=task["subject_id"]).values_list("field", flat=True))
    assert "column" in fields
    ev = Event.objects.get(kind="task.moved")
    assert ev.data["to_column_id"] == done and ev.data["from_column_id"] == task["column_id"]
    assert ev.title == "Build page" and all("Build page" not in str(e.data) for e in AuditEvent.objects.all())


def test_move_needs_edit_rights_in_source_and_member_rights_in_target(crew, project, make_ptask):
    task = make_ptask(who=crew.mel_d)  # creator mel
    body = {"project_id": project["id"], "column_id": column_id(project, "doing")}
    assert crew.mia_d.call("post", tpath(task, "/move"), body).status_code == 403  # owner only
    assert crew.vic_d.call("post", tpath(task, "/move"), body).status_code == 403
    assert crew.out_d.call("post", tpath(task, "/move"), body).status_code == 404
    assert crew.mel_d.call("post", tpath(task, "/move"), body).status_code == 200  # creator
    assert crew.pam_d.call("post", tpath(task, "/move"), {"project_id": project["id"]}).status_code == 200  # manager


def test_move_into_other_project_needs_membership_there(crew, project, make_ptask):
    other = crew.out_d.call("post", "/projects", {"name": "Other", "members": [
        {"user_id": crew.pam.id, "role": "member"}]}).data
    task = make_ptask()
    assert crew.pam_d.call("post", tpath(task, "/move"), {"project_id": other["id"]}).status_code == 422  # mia not member
    task2 = make_ptask(owner_ids=[crew.pam.id])
    assert crew.pam_d.call("post", tpath(task2, "/move"), {"project_id": other["id"]}).status_code == 200
    viewer_target = crew.out_d.call("post", "/projects", {"name": "V", "members": [
        {"user_id": crew.pam.id, "role": "viewer"}]}).data
    assert crew.pam_d.call("post", tpath(task, "/move"), {"project_id": viewer_target["id"]}).status_code == 403
    crew.out_d.call("post", "/projects", {"name": "Closed"})
    assert crew.pam_d.call("post", tpath(task, "/move"), {"project_id": "6f1f9f7e-9d19-4d4b-8f44-0d6a55a6f0a1"}
                           ).status_code == 404


def test_move_validation(crew, project, make_ptask):
    a, b = make_ptask(title="a"), make_ptask(title="b")
    other = crew.pam_d.call("post", "/projects", {"name": "Other", "members": [
        {"user_id": crew.mia.id, "role": "member"}]}).data
    foreign_col = other["columns"][0]["id"]
    assert crew.pam_d.call("post", tpath(a, "/move"), {"project_id": project["id"], "column_id": foreign_col}
                           ).status_code == 422
    assert crew.pam_d.call("post", tpath(a, "/move"), {"column_id": column_id(project, "todo")}).status_code == 422
    doing = column_id(project, "doing")
    assert crew.pam_d.call("post", tpath(a, "/move"), {"project_id": project["id"], "column_id": doing,
                                                         "before_id": b["id"]}).status_code == 422
    assert crew.pam_d.call("post", tpath(a, "/move"), {"project_id": project["id"], "before_id": a["id"]}
                           ).status_code == 422


def test_move_out_to_personal_and_back_in(crew, project, make_ptask):
    task = make_ptask(who=crew.mel_d)
    out = crew.pam_d.call("post", tpath(task, "/move"), {"project_id": None})
    assert out.status_code == 200 and out.data["project_id"] is None and out.data["column_id"] is None
    assert crew.mia_d.call("get", tpath(task)).status_code == 200  # owner on a personal task
    assert crew.vic_d.call("get", tpath(task)).status_code == 404  # but not every member any more
    back = crew.mia_d.call("post", tpath(task, "/move"), {"project_id": project["id"]})
    assert back.status_code == 403  # mia owns it but is neither the creator nor a manager: no edit right
    back = crew.mel_d.call("post", tpath(task, "/move"), {"project_id": project["id"]})
    assert back.status_code == 200 and back.data["column_id"] == column_id(project, "todo")
    assert Project.objects.get(pk=project["id"]).progress == 0


def test_patch_project_id_moves_the_task(crew, project, make_ptask):
    task = crew.pam_d.call("post", "/tasks", {"title": "p"}).data
    resp = crew.pam_d.call("patch", tpath(task), {"version": 1, "project_id": project["id"]})
    assert resp.status_code == 200 and resp.data["project_id"] == project["id"]
    assert resp.data["column_id"] == column_id(project, "todo")


# --- copy -----------------------------------------------------------------------------------------------------


def test_copy_semantics(crew, project, make_ptask):
    label = Label.objects.create(scope="org", name="Urgent")
    task = make_ptask(title="Original", checklist=["one", "two"], approver_ids=[crew.mel.id],
                      description={"text": "secret"}, label_ids=[label.id])
    crew.mia_d.call("patch", tpath(task, f"/checklist/{task['checklist_items'][0]['id']}"), {"done": True})
    crew.mia_d.call("post", f"/subjects/{task['subject_id']}/comments", {"body": {"text": "hello"}})
    row = File(subject_id=task["subject_id"], uploaded_by=crew.mia, name="a.pdf", content_type="application/pdf",
               size=3, sha256_plain=hashlib.sha256(b"abc").hexdigest())
    filestore.save_encrypted(row.blob, b"abc")
    row.save()
    resp = crew.mia_d.call("post", tpath(task, "/copy"), {"project_id": project["id"]})
    assert resp.status_code == 201
    copy = resp.data
    assert copy["id"] != task["id"] and copy["subject_id"] != task["subject_id"] and copy["title"] == "Original"
    assert copy["creator"]["id"] == crew.mia.id and copy["status"] == "open" and copy["progress"] == 0
    assert copy["owner_ids"] == [crew.mia.id] and [a["user"]["id"] for a in copy["approvers"]] == [crew.mel.id]
    assert [i["text"] for i in copy["checklist_items"]] == ["one", "two"]
    assert not any(i["done"] for i in copy["checklist_items"])
    assert copy["description"] == {"text": "secret"} and copy["label_ids"] == [label.id]
    assert copy["project_id"] == project["id"] and copy["column_id"] == column_id(project, "todo")
    assert Comment.objects.filter(subject_id=copy["subject_id"]).count() == 0
    assert list(ChangeHistory.objects.filter(subject_id=copy["subject_id"]).values_list("field", flat=True)) == ["status"]
    copied_file = File.objects.get(subject_id=copy["subject_id"])
    assert copied_file.blob.name == row.blob.name and copied_file.id != row.id and copied_file.sha256_plain == row.sha256_plain
    assert str(Task.objects.get(pk=copy["id"]).copied_from_id) == task["id"]
    assert Subject.objects.filter(pk=copy["subject_id"]).exists()
    assert SubjectLabel.objects.filter(subject_id=copy["subject_id"], label=label).exists()
    download = crew.mia_d.api.client.get(
        f"/api/files/{copied_file.id}", HTTP_AUTHORIZATION=f"Bearer {crew.mia_d.token}")
    assert download.status_code == 200 and download.content == b"abc"


def test_copy_to_personal_and_permission_rules(crew, project, make_ptask):
    task = make_ptask()
    personal = crew.vic_d.call("post", tpath(task, "/copy"), {"project_id": None})  # viewer may copy out of it
    assert personal.status_code == 201 and personal.data["project_id"] is None
    assert personal.data["owner_ids"] == [crew.mia.id] or personal.data["owner_ids"] == [crew.vic.id]
    assert crew.vic_d.call("post", tpath(task, "/copy"), {"project_id": project["id"]}).status_code == 403
    assert crew.out_d.call("post", tpath(task, "/copy"), {}).status_code == 404
    assert crew.boss.call("post", tpath(task, "/copy"), {}).status_code == 404
    crew.mel.grants.remove(Permission.objects.get(code="task.create"))
    assert crew.mel_d.call("post", tpath(task, "/copy"), {"project_id": project["id"]}).status_code == 403


def test_copy_drops_people_who_are_not_in_the_target_project(crew, project, make_ptask):
    other = crew.pam_d.call("post", "/projects", {"name": "Other", "members": [
        {"user_id": crew.vic.id, "role": "member"}]}).data
    task = make_ptask(owner_ids=[crew.mia.id, crew.mel.id])
    copy = crew.pam_d.call("post", tpath(task, "/copy"), {"project_id": other["id"]}).data
    assert copy["owner_ids"] == [crew.pam.id]  # nobody left: the copier owns it


# --- progress cache -----------------------------------------------------------------------------------------------


def test_progress_is_the_average_of_non_cancelled_tasks(crew, project, make_ptask):
    a, b, c = (make_ptask(title=n) for n in "abc")
    assert Project.objects.get(pk=project["id"]).progress == 0
    crew.mia_d.call("patch", tpath(a), {"version": 1, "progress": 100})
    crew.mia_d.call("patch", tpath(b), {"version": 1, "progress": 50})
    assert Project.objects.get(pk=project["id"]).progress == 50  # (100 + 50 + 0) / 3
    crew.pam_d.call("post", tpath(c, "/cancel"))
    assert Project.objects.get(pk=project["id"]).progress == 75  # cancelled excluded
    assert crew.mia_d.call("get", ppath(project)).data["progress"] == 75
    crew.mia_d.call("post", tpath(b, "/complete"))
    assert Project.objects.get(pk=project["id"]).progress == 100
    crew.pam_d.call("post", tpath(b, "/move"), {"project_id": None})
    assert Project.objects.get(pk=project["id"]).progress == 100  # only a remains
    crew.pam_d.call("post", tpath(a, "/move"), {"project_id": None})
    assert Project.objects.get(pk=project["id"]).progress == 0


def test_column_task_counts_in_project_out(crew, project, make_ptask):
    make_ptask()
    make_ptask()
    counts = {c["kind"]: c["task_count"] for c in crew.vic_d.call("get", ppath(project)).data["columns"]}
    assert counts == {"todo": 2, "doing": 0, "done": 0}


# --- views --------------------------------------------------------------------------------------------------------


def iso(**delta):
    return (datetime(2026, 6, 10, 12, tzinfo=timezone.utc) + timedelta(**delta)).isoformat().replace("+00:00", "Z")


def test_board_list_and_filters(crew, project, make_ptask):
    label = Label.objects.create(scope="org", name="L")
    a = make_ptask(title="alpha", due_at=iso(days=5), label_ids=[label.id])
    b = make_ptask(title="beta", owner_ids=[crew.mel.id])
    c = make_ptask(title="gamma", due_at=iso(days=1))
    crew.pam_d.call("post", tpath(c, "/move"), {"project_id": project["id"], "column_id": column_id(project, "doing")})
    crew.pam_d.call("post", tpath(b, "/cancel"))
    cols = board(crew.vic_d, project)["columns"]
    assert [x["kind"] for x in cols] == ["todo", "doing", "done"]
    assert ids_in(cols[0]) == [a["id"], b["id"]] and ids_in(cols[1]) == [c["id"]]
    listed = crew.vic_d.call("get", ppath(project, "/tasks?view=list")).data
    assert listed["columns"] == [] and [t["id"] for t in listed["tasks"]] == [c["id"], a["id"], b["id"]]  # by due date
    flat = lambda q: [t["id"] for t in crew.mia_d.call("get", ppath(project, f"/tasks?view=list&{q}")).data["tasks"]]  # noqa: E731
    assert flat("q=alp") == [a["id"]] and flat("status=cancelled") == [b["id"]]
    assert flat(f"owner={crew.mel.id}") == [b["id"]] and flat(f"label={label.id}") == [a["id"]]
    assert flat("status=open&q=zzz") == []
    assert ids_in(board(crew.mia_d, project, status="open")["columns"][0]) == [a["id"]]


def test_calendar_range_uses_due_or_start(crew, project, make_ptask):
    inside = make_ptask(title="in", due_at=iso(days=2))
    starting = make_ptask(title="start", start_at=iso(days=3), due_at=iso(days=40))
    outside = make_ptask(title="out", due_at=iso(days=30))
    make_ptask(title="none")
    path = ppath(project, "/tasks?view=calendar&from={}&to={}")
    got = crew.mia_d.call("get", path.format(iso(), iso(days=7))).data["tasks"]
    assert [t["id"] for t in got] == [inside["id"], starting["id"]]
    got = crew.mia_d.call("get", path.format(iso(days=29), iso(days=31))).data["tasks"]
    assert [t["id"] for t in got] == [outside["id"]]
    assert crew.mia_d.call("get", ppath(project, "/tasks?view=calendar")).status_code == 422
    assert crew.mia_d.call("get", path.format(iso(days=5), iso())).status_code == 422
    assert crew.mia_d.call("get", ppath(project, "/tasks?view=gantt")).status_code == 422


def test_views_are_members_only(crew, project, make_ptask):
    make_ptask()
    assert crew.out_d.call("get", ppath(project, "/tasks")).status_code == 404
    assert crew.boss.call("get", ppath(project, "/tasks")).status_code == 404


# --- inbox / follow-up with project tasks ------------------------------------------------------------------------


def test_inbox_and_followup_with_project_tasks(crew, project, make_ptask):
    task = make_ptask(who=crew.mel_d)  # creator mel, owner mia
    assert [t["id"] for t in crew.mia_d.call("get", "/tasks?box=inbox").data] == [task["id"]]
    assert [t["id"] for t in crew.mel_d.call("get", "/tasks?box=followup").data] == [task["id"]]
    assert crew.vic_d.call("get", "/tasks?box=inbox").data == []
    assert [t["id"] for t in crew.vic_d.call("get", "/tasks?box=all").data] == [task["id"]]
    crew.pam_d.call("put", ppath(project, "/members"), [{"user_id": crew.pam.id, "role": "manager"},
                                                          {"user_id": crew.mel.id, "role": "member"}])
    assert crew.mia_d.call("get", "/tasks?box=inbox").data == []  # owner removed from the project: not visible
