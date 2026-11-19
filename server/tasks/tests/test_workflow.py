import json

from accounts.models import AuditEvent, Notification
from workspace.models import ChangeHistory, Comment, Event, EventRecipient
from workspace.textbox import open_text


def url(task, tail=""):
    return f"/tasks/{task['id']}{tail}"


def status(who, task):
    return who.call("get", url(task)).data["status"]


def test_complete_without_approvers_is_done(team, make_task):
    task = make_task()
    assert team.cat_d.call("post", url(task, "/complete")).status_code == 403  # creator is not an owner
    assert team.fay_d.call("post", url(task, "/complete")).status_code == 404
    out = team.olga_d.call("post", url(task, "/complete"), {"note": "all done"})
    assert out.status_code == 200 and out.data["status"] == "done" and out.data["progress"] == 100
    assert out.data["completed_at"] is not None
    assert team.olga_d.call("post", url(task, "/complete")).status_code == 409  # already done
    note = Comment.objects.get(subject_id=task["subject_id"])
    assert note.kind == "report" and open_text(note.body) == "all done" and note.author_id == team.olga.id


def test_complete_accepts_empty_body(team, make_task):
    task = make_task()
    assert team.olga_d.call("post", url(task, "/complete")).status_code == 200


def test_serial_approvers_in_position_order(team, approved_flow, django_capture_on_commit_callbacks):
    task = approved_flow
    with django_capture_on_commit_callbacks(execute=True):
        out = team.olga_d.call("post", url(task, "/complete")).data
    assert out["status"] == "awaiting_approval"
    approve = {"decision": "approve", "note": ""}
    assert team.ben_d.call("post", url(task, "/decision"), approve).status_code == 409  # not ben's turn yet
    assert team.fay_d.call("post", url(task, "/decision"), approve).status_code == 403
    assert team.olga_d.call("post", url(task, "/decision"), approve).status_code == 403
    assert team.abe_d.call("get", url(task)).data["can"]["approve"] is True
    assert team.ben_d.call("get", url(task)).data["can"]["approve"] is False
    with django_capture_on_commit_callbacks(execute=True):
        mid = team.abe_d.call("post", url(task, "/decision"), approve).data
    assert mid["status"] == "awaiting_approval"
    assert [a["decision"] for a in mid["approvers"]] == ["approved", ""]
    assert team.abe_d.call("post", url(task, "/decision"), approve).status_code == 409  # already decided
    done = team.ben_d.call("post", url(task, "/decision"), approve).data
    assert done["status"] == "done" and done["completed_at"]
    kinds = list(Event.objects.filter(subject_id=task["subject_id"]).order_by("id").values_list("kind", flat=True))
    assert kinds == ["task.created", "task.completed", "task.approved", "task.approved"]
    final = Event.objects.filter(kind="task.approved").order_by("id").last()
    assert final.data["final"] is True


def test_inbox_follows_the_current_approver(team, approved_flow):
    task = approved_flow
    inbox = lambda who: {t["id"] for t in who.call("get", "/tasks?box=inbox").data}  # noqa: E731
    assert inbox(team.abe_d) == set() and inbox(team.olga_d) == {task["id"]}
    team.olga_d.call("post", url(task, "/complete"))
    assert inbox(team.olga_d) == set() and inbox(team.abe_d) == {task["id"]} and inbox(team.ben_d) == set()
    team.abe_d.call("post", url(task, "/decision"), {"decision": "approve"})
    assert inbox(team.abe_d) == set() and inbox(team.ben_d) == {task["id"]}


def test_next_approver_is_notified(team, approved_flow, django_capture_on_commit_callbacks):
    task = approved_flow
    before = Notification.objects.count()
    with django_capture_on_commit_callbacks(execute=True):
        team.olga_d.call("post", url(task, "/complete"))
    first = list(Notification.objects.order_by("id")[before:])
    assert [n.user_id for n in first] == [team.abe.id] and first[0].kind == "task.approval_needed"
    assert first[0].data["subject_id"] == task["subject_id"] and first[0].data["object_id"] == task["id"]
    before = Notification.objects.count()
    with django_capture_on_commit_callbacks(execute=True):
        team.abe_d.call("post", url(task, "/decision"), {"decision": "approve"})
    assert [n.user_id for n in Notification.objects.order_by("id")[before:]] == [team.ben.id]


def test_rejection_reopens_with_note_and_restarts_approval(team, approved_flow):
    task = approved_flow
    team.olga_d.call("post", url(task, "/complete"))
    assert team.abe_d.call("post", url(task, "/decision"), {"decision": "reject", "note": " "}).status_code == 422
    out = team.abe_d.call("post", url(task, "/decision"), {"decision": "reject", "note": "numbers are off"}).data
    assert out["status"] == "open" and out["approvers"][0]["decision"] == "rejected"
    note = Comment.objects.get(subject_id=task["subject_id"])
    assert note.kind == "report" and note.author_id == team.abe.id and open_text(note.body) == "numbers are off"
    assert "numbers" not in json.dumps(note.body)
    assert Event.objects.filter(kind="task.rejected").count() == 1
    # the owner completes again: everybody decides again, starting with abe
    again = team.olga_d.call("post", url(task, "/complete")).data
    assert [a["decision"] for a in again["approvers"]] == ["", ""]
    assert team.ben_d.call("post", url(task, "/decision"), {"decision": "approve"}).status_code == 409


def test_reopen_and_cancel_are_creator_only(team, approved_flow):
    task = approved_flow
    assert team.olga_d.call("post", url(task, "/cancel")).status_code == 403
    assert team.cat_d.call("post", url(task, "/reopen")).status_code == 409  # open tasks cannot be reopened
    assert team.cat_d.call("post", url(task, "/cancel")).data["status"] == "cancelled"
    assert team.cat_d.call("post", url(task, "/cancel")).status_code == 409
    assert team.olga_d.call("post", url(task, "/complete")).status_code == 409
    assert team.cat_d.call("patch", url(task), {"version": 1, "title": "x"}).status_code == 409
    assert team.olga_d.call("post", url(task, "/reopen")).status_code == 403
    assert team.cat_d.call("post", url(task, "/reopen")).data["status"] == "open"


def test_reopen_after_done_resets_decisions(team, approved_flow):
    task = approved_flow
    team.olga_d.call("post", url(task, "/complete"))
    team.abe_d.call("post", url(task, "/decision"), {"decision": "approve"})
    team.ben_d.call("post", url(task, "/decision"), {"decision": "approve"})
    assert status(team.cat_d, task) == "done"
    out = team.cat_d.call("post", url(task, "/reopen")).data
    assert out["status"] == "open" and out["completed_at"] is None
    assert [a["decision"] for a in out["approvers"]] == ["", ""]


def test_status_changes_write_history_and_audit_without_titles(team, approved_flow):
    task = approved_flow
    team.olga_d.call("post", url(task, "/complete"))
    team.abe_d.call("post", url(task, "/decision"), {"decision": "reject", "note": "no"})
    team.cat_d.call("post", url(task, "/cancel"))
    changes = [(h.field, h.old, h.new) for h in ChangeHistory.objects.filter(subject_id=task["subject_id"])
               if h.field == "status"]
    assert ("status", "open", "awaiting_approval") in changes and ("status", "awaiting_approval", "open") in changes
    assert ("status", "open", "cancelled") in changes
    actions = list(AuditEvent.objects.filter(action__startswith="task_").values_list("action", flat=True))
    assert actions == ["task_created", "task_completed", "task_decision", "task_cancelled"]
    assert "Quarterly" not in json.dumps(list(AuditEvent.objects.values_list("data", "target")))


def test_event_recipients_are_the_audience_minus_the_actor(team, approved_flow):
    task = approved_flow
    created = Event.objects.get(kind="task.created", subject_id=task["subject_id"])
    got = set(EventRecipient.objects.filter(event=created).values_list("user_id", flat=True))
    assert got == {team.olga.id, team.abe.id, team.ben.id, team.fay.id}  # not the creator (actor), not outsiders
    assert created.title == "Quarterly report" and created.data["object_id"] == task["id"]
    team.olga_d.call("patch", url(task), {"version": 1, "progress": 10})
    updated = Event.objects.filter(kind="task.updated", subject_id=task["subject_id"]).get()
    got = set(EventRecipient.objects.filter(event=updated).values_list("user_id", flat=True))
    assert got == {team.cat.id, team.abe.id, team.ben.id, team.fay.id} and updated.data["fields"] == ["progress"]
    assert team.out.id not in got and team.manager.id not in got


def test_created_notifications_go_to_new_people_not_the_creator(team, make_task, django_capture_on_commit_callbacks):
    before = Notification.objects.count()
    with django_capture_on_commit_callbacks(execute=True):
        make_task(approver_ids=[team.abe.id], follower_ids=[team.fay.id])
    got = {n.user_id for n in Notification.objects.order_by("id")[before:]}
    assert got == {team.olga.id, team.abe.id, team.fay.id}


def test_removing_the_waiting_approver_moves_on(team, approved_flow, django_capture_on_commit_callbacks):
    task = approved_flow
    team.olga_d.call("post", url(task, "/complete"))
    body = {"owner_ids": [team.olga.id], "approver_ids": [team.ben.id]}
    before = Notification.objects.count()
    with django_capture_on_commit_callbacks(execute=True):
        out = team.cat_d.call("put", url(task, "/people"), body).data
    assert out["status"] == "awaiting_approval"
    assert [n.user_id for n in Notification.objects.order_by("id")[before:]] == [team.ben.id]
    team.cat_d.call("put", url(task, "/people"), {"owner_ids": [team.olga.id]})
    assert status(team.cat_d, task) == "done"  # nobody left to approve


def test_report_comment_sets_progress_only_for_owners(team, make_task):
    task = make_task(follower_ids=[team.fay.id])
    path = f"/subjects/{task['subject_id']}/comments"
    body = {"kind": "report", "body": {"text": "half way"}, "progress": 50}
    assert team.fay_d.call("post", path, body).status_code == 403
    assert team.cat_d.call("post", path, body).status_code == 403
    ok = team.olga_d.call("post", path, body)
    assert ok.status_code == 201 and ok.data["progress"] == 50 and ok.data["kind"] == "report"
    assert team.olga_d.call("get", url(task)).data["progress"] == 50
    hist = ChangeHistory.objects.filter(subject_id=task["subject_id"], field="progress").get()
    assert (hist.old, hist.new, hist.actor_id) == (0, 50, team.olga.id)
    # checklist mode computes progress itself
    team.cat_d.call("patch", url(task), {"version": 1, "progress_mode": "checklist"})
    assert team.olga_d.call("post", path, body).status_code == 422
    team.olga_d.call("post", url(task, "/complete"))
    assert team.olga_d.call("post", path, body).status_code == 403  # closed: owners no longer report


def test_approval_note_is_visible_in_comment_thread(team, approved_flow):
    task = approved_flow
    team.olga_d.call("post", url(task, "/complete"))
    team.abe_d.call("post", url(task, "/decision"), {"decision": "reject", "note": "redo it"})
    thread = team.fay_d.call("get", f"/subjects/{task['subject_id']}/comments").data
    assert [c["body"]["text"] for c in thread] == ["redo it"] and thread[0]["author"]["id"] == team.abe.id
    assert team.cat_d.call("get", url(task)).data["comment_count"] == 1
