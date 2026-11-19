import json

import pytest
from django.db import connection, transaction
from django.db.utils import DatabaseError

from accounts.models import AuditEvent, Notification
from tasks.models import ChecklistItem, Task, TaskPerson
from workspace.models import ChangeHistory, Event, SubjectLabel

PROJECT = "6f1f9f7e-9d19-4d4b-8f44-0d6a55a6f0a1"


def test_create_returns_task_out_with_defaults(team, make_task):
    data = make_task(description={"text": "secret plan"}, priority="high", checklist=["a", "b"])
    assert data["status"] == "open" and data["priority"] == "high" and data["project_id"] is None
    assert data["owner_ids"] == [team.olga.id] and data["creator"]["id"] == team.cat.id
    assert data["description"] == {"text": "secret plan"} and data["version"] == 1
    assert data["checklist"] == {"done": 0, "total": 2}
    assert [i["text"] for i in data["checklist_items"]] == ["a", "b"]
    assert data["my_roles"] == ["creator"] and data["unseen"] is False
    assert data["can"]["edit"] and not data["can"]["progress"] and data["can"]["comment"]
    assert data["comment_count"] == 0 and data["file_count"] == 0


def test_owner_defaults_to_creator(team):
    data = team.cat_d.call("post", "/tasks", {"title": "x"}).data
    assert data["owner_ids"] == [team.cat.id] and data["my_roles"] == ["creator", "owner"]


def test_create_needs_task_create_grant(team, make_user, login):
    plain = login(make_user("plain@corp.test"))
    assert plain.call("post", "/tasks", {"title": "x"}).status_code == 403


def test_unknown_project_id_is_404(team):
    assert team.cat_d.call("post", "/tasks", {"title": "x", "project_id": PROJECT}).status_code == 404


def test_unknown_person_or_label_is_422(team):
    assert team.cat_d.call("post", "/tasks", {"title": "x", "owner_ids": [99999]}).status_code == 422
    assert team.cat_d.call("post", "/tasks", {"title": "x", "label_ids": [99999]}).status_code == 422


def test_description_is_encrypted_at_rest_and_title_is_not(make_task):
    data = make_task(title="Visible title", description={"text": "very private words"})
    task = Task.objects.get(pk=data["id"])
    assert task.description["v"] == 3 and "ct" in task.description
    assert "very private words" not in json.dumps(task.description)
    assert task.title == "Visible title" and task.subject.module == "tasks" and task.subject.kind == "task"


def test_visibility_matrix(team, approved_flow):
    tid = approved_flow["id"]
    for who in (team.cat_d, team.olga_d, team.abe_d, team.ben_d, team.fay_d):
        assert who.call("get", f"/tasks/{tid}").status_code == 200
    assert team.out_d.call("get", f"/tasks/{tid}").status_code == 404
    assert team.boss.call("get", f"/tasks/{tid}").status_code == 404  # the manager gets nothing automatically
    assert team.boss.call("get", "/tasks").data == []
    assert team.out_d.call("post", f"/tasks/{tid}/seen").status_code == 404


def test_permission_matrix_flags(team, approved_flow):
    tid = approved_flow["id"]

    def can(who):
        return who.call("get", f"/tasks/{tid}").data["can"]

    assert can(team.cat_d)["edit"] and not can(team.cat_d)["progress"]
    assert can(team.olga_d)["progress"] and can(team.olga_d)["complete"] and not can(team.olga_d)["edit"]
    assert not can(team.abe_d)["approve"]  # not awaiting yet
    assert not any(can(team.fay_d)[k] for k in ("edit", "progress", "approve")) and can(team.fay_d)["comment"]


def test_patch_rules_creator_owner_follower(team, make_task):
    task = make_task(follower_ids=[team.fay.id])
    path = f"/tasks/{task['id']}"
    assert team.olga_d.call("patch", path, {"version": 1, "title": "Hijack"}).status_code == 403
    assert team.fay_d.call("patch", path, {"version": 1, "progress": 10}).status_code == 403
    assert team.cat_d.call("patch", path, {"version": 1, "progress": 10}).status_code == 403  # creator not owner
    ok = team.olga_d.call("patch", path, {"version": 1, "progress": 40})
    assert ok.status_code == 200 and ok.data["progress"] == 40 and ok.data["version"] == 2
    ok = team.cat_d.call("patch", path, {"version": 2, "title": "New", "due_at": "2030-01-01T00:00:00Z"})
    assert ok.data["title"] == "New" and ok.data["due_at"].startswith("2030-01-01") and ok.data["version"] == 3


def test_version_conflict_is_409(team, make_task):
    task = make_task()
    path = f"/tasks/{task['id']}"
    assert team.cat_d.call("patch", path, {"version": 1, "title": "A"}).status_code == 200
    assert team.cat_d.call("patch", path, {"version": 1, "title": "B"}).status_code == 409
    assert Task.objects.get(pk=task["id"]).title == "A"


def test_patch_unknown_project_id_is_404(team, make_task):
    task = make_task()
    resp = team.cat_d.call("patch", f"/tasks/{task['id']}", {"version": 1, "project_id": PROJECT})
    assert resp.status_code == 404


def test_history_rows_hide_encrypted_values(team, make_task):
    task = make_task(description={"text": "first secret"})
    path = f"/tasks/{task['id']}"
    team.cat_d.call("patch", path, {"version": 1, "title": "Renamed", "description": {"text": "second secret"}})
    rows = {h.field: h for h in ChangeHistory.objects.filter(subject__task__pk=task["id"])}
    assert rows["title"].old == "Quarterly report" and rows["title"].new == "Renamed"
    assert rows["description"].new == {"changed": True} and rows["description"].old is None
    dumped = json.dumps([[h.new, h.old] for h in rows.values()])
    assert "secret" not in dumped
    shown = team.cat_d.call("get", f"/subjects/{task['subject_id']}/history").data
    assert {"title", "description", "status"} <= {h["field"] for h in shown}
    assert team.out_d.call("get", f"/subjects/{task['subject_id']}/history").status_code == 404


def test_no_change_patch_keeps_version(team, make_task):
    task = make_task()
    resp = team.cat_d.call("patch", f"/tasks/{task['id']}", {"version": 1, "title": task["title"]})
    assert resp.data["version"] == 1


def test_checklist_progress_mode_computes_progress(team, make_task):
    task = make_task(checklist=["a", "b", "c", "d"])
    path = f"/tasks/{task['id']}"
    assert team.cat_d.call("patch", path, {"version": 1, "progress_mode": "checklist"}).data["progress"] == 0
    items = team.olga_d.call("get", path).data["checklist_items"]
    assert team.olga_d.call("patch", f"{path}/checklist/{items[0]['id']}", {"done": True}).data["progress"] == 25
    out = team.olga_d.call("patch", f"{path}/checklist/{items[1]['id']}", {"done": True}).data
    assert out["progress"] == 50 and out["checklist"] == {"done": 2, "total": 4}
    assert out["checklist_items"][0]["done_by"]["id"] == team.olga.id
    assert team.olga_d.call("patch", path, {"version": 2, "progress": 90}).status_code == 422
    added = team.olga_d.call("post", f"{path}/checklist", {"text": "e"}).data
    assert added["progress"] == 40 and added["checklist"]["total"] == 5
    removed = team.olga_d.call("patch", f"{path}/checklist/{items[2]['id']}", {"active": False}).data
    assert removed["checklist"]["total"] == 4 and removed["progress"] == 50


def test_checklist_permissions_and_order(team, make_task):
    task = make_task(checklist=["a", "b", "c"], follower_ids=[team.fay.id])
    path = f"/tasks/{task['id']}"
    ids = [i["id"] for i in team.cat_d.call("get", path).data["checklist_items"]]
    assert team.fay_d.call("post", f"{path}/checklist", {"text": "z"}).status_code == 403
    assert team.cat_d.call("patch", f"{path}/checklist/{ids[0]}", {"done": True}).status_code == 403  # owners tick
    assert team.cat_d.call("post", f"{path}/checklist", {"text": "d"}).status_code == 200
    ids = [i["id"] for i in team.cat_d.call("get", path).data["checklist_items"]]
    new = [ids[3], ids[0], ids[1], ids[2]]
    out = team.olga_d.call("put", f"{path}/checklist/order", {"item_ids": new}).data
    assert [i["id"] for i in out["checklist_items"]] == new
    assert team.olga_d.call("put", f"{path}/checklist/order", {"item_ids": new[:2]}).status_code == 422
    assert ChecklistItem.objects.filter(task_id=task["id"]).order_by("rank").first().id == new[0]


def test_people_put_is_creator_only_and_notifies_new_people(team, make_task, django_capture_on_commit_callbacks):
    task = make_task()
    path = f"/tasks/{task['id']}/people"
    body = {"owner_ids": [team.olga.id, team.abe.id], "approver_ids": [team.ben.id], "follower_ids": [team.fay.id]}
    assert team.olga_d.call("put", path, body).status_code == 403
    assert team.out_d.call("put", path, body).status_code == 404
    before = Notification.objects.count()
    with django_capture_on_commit_callbacks(execute=True):
        out = team.cat_d.call("put", path, body).data
    assert [o["id"] for o in out["owners"]] == [team.olga.id, team.abe.id]
    assert [a["user"]["id"] for a in out["approvers"]] == [team.ben.id]
    new = Notification.objects.order_by("id")[before:]
    assert {n.user_id for n in new} == {team.abe.id, team.ben.id, team.fay.id}  # olga was already on it
    assert all(n.data["module"] == "tasks" and n.data["object_id"] == task["id"] for n in new)
    team.cat_d.call("put", path, {"owner_ids": [team.olga.id]})  # removing only deactivates rows
    assert TaskPerson.objects.filter(task_id=task["id"], user=team.abe, role="owner", active=False).exists()
    assert team.abe_d.call("get", f"/tasks/{task['id']}").status_code == 404


def test_boxes_inbox_and_followup(team, make_task):
    owned = make_task(title="owned")
    followed = make_task(title="followed", follower_ids=[team.fay.id])

    def ids(who, box):
        return {t["id"] for t in who.call("get", f"/tasks?box={box}").data}

    assert ids(team.olga_d, "inbox") == {owned["id"], followed["id"]}
    assert ids(team.olga_d, "followup") == set()
    assert ids(team.cat_d, "followup") == {owned["id"], followed["id"]}
    assert ids(team.cat_d, "inbox") == set()
    assert ids(team.fay_d, "followup") == {followed["id"]} and ids(team.fay_d, "inbox") == set()
    assert ids(team.fay_d, "all") == {followed["id"]}
    assert team.cat_d.call("get", "/tasks?box=nope").status_code == 422


def test_list_filters_and_paging(team, make_task):
    a = make_task(title="Alpha budget", due_at="2030-01-01T00:00:00Z")
    b = make_task(title="Beta plan", due_at="2031-01-01T00:00:00Z")
    c = make_task(title="Gamma")

    def get(qs):
        return [t["id"] for t in team.cat_d.call("get", f"/tasks?{qs}").data]

    assert get("q=budget") == [a["id"]]
    assert get("due_before=2030-06-01T00:00:00Z") == [a["id"]]
    assert set(get("status=open")) == {a["id"], b["id"], c["id"]} and get("status=done") == []
    assert len(get("limit=2")) == 2 and len(get("limit=2&offset=2")) == 1
    label = team.cat_d.call("post", "/labels", {"name": "Mine", "color": 1, "scope": "personal"}).data
    team.cat_d.call("put", f"/subjects/{b['subject_id']}/labels", {"label_ids": [label["id"]]})
    assert get(f"label={label['id']}") == [b["id"]]
    assert team.cat_d.call("get", f"/tasks/{b['id']}").data["label_ids"] == [label["id"]]
    assert team.olga_d.call("get", f"/tasks/{b['id']}").data["label_ids"] == []  # personal label
    assert SubjectLabel.objects.filter(subject_id=b["subject_id"]).count() == 1


def test_seen_and_unseen_flag(team, make_task):
    task = make_task()
    path = f"/tasks/{task['id']}"
    assert team.olga_d.call("get", path).data["unseen"] is True
    assert team.olga_d.call("post", f"{path}/seen").status_code == 204
    assert team.olga_d.call("get", path).data["unseen"] is False
    team.cat_d.call("patch", path, {"version": 1, "title": "Changed"})
    assert team.olga_d.call("get", path).data["unseen"] is True
    seen = team.cat_d.call("get", f"/subjects/{task['subject_id']}/seen").data
    assert {s["user"]["id"] for s in seen} == {team.cat.id, team.olga.id}


def test_module_off_in_brand_means_404(team, make_task, brand_dir):
    task = make_task()
    brand_dir(modules=["letters"])
    for method, path in (("get", "/tasks"), ("get", f"/tasks/{task['id']}"), ("post", "/tasks"),
                         ("post", f"/tasks/{task['id']}/complete"), ("post", f"/tasks/{task['id']}/seen")):
        body = {"title": "x"} if path == "/tasks" and method == "post" else None
        assert team.cat_d.call(method, path, body).status_code == 404, path
    assert team.cat_d.call("get", f"/subjects/{task['subject_id']}/comments").status_code == 404


def test_tables_refuse_delete(make_task):
    task = make_task(checklist=["a"])
    for table in ("tasks_task", "tasks_taskperson", "tasks_checklistitem"):
        with pytest.raises(DatabaseError, match="not allowed"), transaction.atomic():
            with connection.cursor() as cur:
                cur.execute(f"DELETE FROM {table}")
    assert Task.objects.filter(pk=task["id"]).exists()


def test_audit_rows_carry_ids_not_titles(team, make_task):
    task = make_task(title="Confidential merger")
    team.cat_d.call("post", f"/tasks/{task['id']}/cancel")
    rows = AuditEvent.objects.filter(action__startswith="task_")
    assert {r.action for r in rows} == {"task_created", "task_cancelled"}
    assert "Confidential" not in json.dumps([[r.target, r.data] for r in rows])
    assert Event.objects.filter(kind="task.created").exists()
