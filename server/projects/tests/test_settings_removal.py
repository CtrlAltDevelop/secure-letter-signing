from datetime import timedelta

from django.utils import timezone

from accounts.models import AuditEvent, Notification
from projects.models import Project
from tasks.models import RemovalRequest, Task
from projects.tests.conftest import column_id
from workspace.models import ChangeHistory, Event


def setting(crew, project, **flags):
    resp = crew.pam_d.call("patch", f"/projects/{project['id']}", flags)
    assert resp.status_code == 200, resp.content
    return resp.data


def stamp(days):
    return (timezone.now() + timedelta(days=days)).isoformat()


# --- settings -------------------------------------------------------------------------------------------------


def test_flags_default_and_only_managers_change_them(crew, project):
    assert (project["members_can_edit_tasks"], project["members_can_extend"], project["require_removal_approval"]) == (
        True, True, False)
    url = f"/projects/{project['id']}"
    assert crew.mia_d.call("patch", url, {"members_can_extend": False}).status_code == 403
    out = setting(crew, project, members_can_extend=False, require_removal_approval=True)
    assert out["members_can_extend"] is False and out["require_removal_approval"] is True
    assert crew.pam_d.call("patch", url, {"members_can_extend": None}).status_code == 422
    assert ChangeHistory.objects.filter(subject__project__pk=project["id"], field="members_can_extend").count() == 1


def test_create_with_flags(crew):
    resp = crew.pam_d.call("post", "/projects", {"name": "P", "members_can_edit_tasks": False})
    assert resp.status_code == 201 and resp.data["members_can_edit_tasks"] is False


def test_members_without_edit_flag_cannot_create_or_edit_but_managers_can(crew, project, make_ptask):
    task = make_ptask(who=crew.pam_d)
    mine = make_ptask()
    setting(crew, project, members_can_edit_tasks=False)
    body = {"title": "x", "project_id": project["id"], "owner_ids": [crew.mia.id]}
    assert crew.mia_d.call("post", "/tasks", body).status_code == 403
    assert crew.pam_d.call("post", "/tasks", body).status_code == 201
    got = crew.mia_d.call("get", f"/tasks/{mine['id']}").data
    assert got["can"]["edit"] is False
    assert crew.mia_d.call("patch", f"/tasks/{mine['id']}", {"version": got["version"], "title": "y"}).status_code == 403
    assert crew.pam_d.call("patch", f"/tasks/{task['id']}", {"version": 1, "title": "y"}).status_code == 200
    assert crew.mia_d.call("patch", f"/tasks/{mine['id']}", {"version": got["version"], "progress": 40}
                           ).status_code == 200  # owners still report progress


def test_members_without_extend_flag_cannot_move_due_dates_later(crew, project, make_ptask):
    task = make_ptask(due_at=stamp(5))
    tid = task["id"]
    setting(crew, project, members_can_extend=False)
    version = crew.mia_d.call("get", f"/tasks/{tid}").data["version"]
    url = f"/tasks/{tid}"
    assert crew.mia_d.call("patch", url, {"version": version, "due_at": stamp(9)}).status_code == 403
    assert crew.mia_d.call("patch", url, {"version": version, "due_at": None}).status_code == 403
    sooner = crew.mia_d.call("patch", url, {"version": version, "due_at": stamp(2)})
    assert sooner.status_code == 200
    later = crew.pam_d.call("patch", url, {"version": sooner.data["version"], "due_at": stamp(20)})
    assert later.status_code == 200


def test_first_deadline_is_not_an_extension(crew, project, make_ptask):
    task = make_ptask()
    setting(crew, project, members_can_extend=False)
    resp = crew.mia_d.call("patch", f"/tasks/{task['id']}", {"version": task["version"], "due_at": stamp(3)})
    assert resp.status_code == 200


def test_project_manager_can_reopen_a_completed_task(crew, make_ptask):
    task = make_ptask(who=crew.pam_d)
    assert crew.mia_d.call("post", f"/tasks/{task['id']}/complete").data["status"] == "done"
    assert crew.mia_d.call("post", f"/tasks/{task['id']}/reopen").status_code == 403  # owner, not creator/manager
    resp = crew.pam_d.call("post", f"/tasks/{task['id']}/reopen")
    assert resp.status_code == 200 and resp.data["status"] == "open"


# --- weight ---------------------------------------------------------------------------------------------------


def test_weight_default_validation_and_patch(crew, make_ptask):
    task = make_ptask()
    assert task["weight"] == 1
    heavy = make_ptask(weight=10)
    assert heavy["weight"] == 10
    bad = {"title": "x", "weight": 0}
    assert crew.mia_d.call("post", "/tasks", bad).status_code == 422
    assert crew.mia_d.call("post", "/tasks", {**bad, "weight": 11}).status_code == 422
    resp = crew.mia_d.call("patch", f"/tasks/{task['id']}", {"version": 1, "weight": 4})
    assert resp.status_code == 200 and resp.data["weight"] == 4


def test_project_progress_is_a_weighted_average(crew, project, make_ptask):
    light, heavy = make_ptask(weight=1), make_ptask(weight=3)
    crew.mia_d.call("patch", f"/tasks/{light['id']}", {"version": 1, "progress": 100})
    crew.mia_d.call("patch", f"/tasks/{heavy['id']}", {"version": 1, "progress": 20})
    assert Project.objects.get(pk=project["id"]).progress == round((100 * 1 + 20 * 3) / 4)
    crew.mia_d.call("patch", f"/tasks/{heavy['id']}", {"version": 2, "weight": 1})
    assert Project.objects.get(pk=project["id"]).progress == 60


def test_cancelled_tasks_do_not_weigh(crew, project, make_ptask):
    done, other = make_ptask(weight=1), make_ptask(weight=9)
    crew.mia_d.call("patch", f"/tasks/{done['id']}", {"version": 1, "progress": 100})
    crew.pam_d.call("post", f"/tasks/{other['id']}/cancel")
    assert Project.objects.get(pk=project["id"]).progress == 100


# --- removal approval -----------------------------------------------------------------------------------------


def removal(who, task, note="not needed"):
    return who.call("post", f"/tasks/{task['id']}/removal-request", {"note": note})


def decide(who, task, decision="approve", note=""):
    return who.call("post", f"/tasks/{task['id']}/removal-decision", {"decision": decision, "note": note})


def test_without_the_setting_requests_are_refused_and_cancel_works(crew, make_ptask):
    task = make_ptask(who=crew.mia_d)
    assert removal(crew.mia_d, task).status_code == 409
    assert crew.mia_d.call("post", f"/tasks/{task['id']}/cancel").data["status"] == "cancelled"


def test_with_the_setting_creators_must_ask_and_managers_may_cancel(crew, project, make_ptask):
    setting(crew, project, require_removal_approval=True)
    task, other = make_ptask(), make_ptask()
    assert crew.mia_d.call("post", f"/tasks/{task['id']}/cancel").status_code == 403
    assert crew.pam_d.call("post", f"/tasks/{other['id']}/cancel").data["status"] == "cancelled"


def test_request_permissions(crew, project, make_ptask):
    setting(crew, project, require_removal_approval=True)
    task = make_ptask(who=crew.pam_d, owner_ids=[crew.mia.id])  # pam created, mia owns
    expected = {"mel_d": 403, "vic_d": 403, "out_d": 404, "boss": 404, "mia_d": 200}
    for name, code in expected.items():
        assert removal(getattr(crew, name), task).status_code == code, name
    assert removal(crew.mia_d, task).status_code == 409  # already pending (mia's request above)


def test_request_shows_pending_and_notifies_managers(crew, project, make_ptask, django_capture_on_commit_callbacks):
    setting(crew, project, require_removal_approval=True)
    task = make_ptask()
    with django_capture_on_commit_callbacks(execute=True):
        resp = removal(crew.mia_d, task, "wrong plan")
    assert resp.status_code == 200 and resp.data["removal"]["status"] == "pending"
    assert resp.data["removal"]["note"] == "wrong plan" and resp.data["can"]["request_removal"] is True
    assert Notification.objects.filter(user=crew.pam, kind="task.removal_requested").count() == 1
    assert not Notification.objects.filter(user=crew.mel, kind="task.removal_requested").exists()
    assert Event.objects.filter(kind="task.removal_requested", recipients__user=crew.pam).exists()
    assert "wrong plan" not in str(RemovalRequest.objects.get().note)
    assert all("Build page" not in str(e.data) for e in AuditEvent.objects.all())


def test_decision_permissions_and_state(crew, project, make_ptask):
    setting(crew, project, require_removal_approval=True)
    task = make_ptask()
    assert decide(crew.pam_d, task).status_code == 409  # nothing pending
    removal(crew.mia_d, task)
    for name, code in {"mia_d": 403, "mel_d": 403, "vic_d": 403, "out_d": 404}.items():
        assert decide(getattr(crew, name), task).status_code == code, name
    assert decide(crew.pam_d, task, "reject").status_code == 422  # needs a note


def test_approval_cancels_hides_and_notifies(crew, project, make_ptask, django_capture_on_commit_callbacks):
    setting(crew, project, require_removal_approval=True)
    keep, task = make_ptask(), make_ptask()
    crew.mia_d.call("patch", f"/tasks/{keep['id']}", {"version": 1, "progress": 100})
    removal(crew.mia_d, task)
    with django_capture_on_commit_callbacks(execute=True):
        resp = decide(crew.pam_d, task, "approve", "ok")
    assert resp.status_code == 200 and resp.data["status"] == "cancelled" and resp.data["hidden"] is True
    assert resp.data["removal"]["status"] == "approved" and resp.data["removal"]["decision_note"] == "ok"
    assert Notification.objects.filter(user=crew.mia, kind="task.removal_approved").count() == 1
    assert Event.objects.filter(kind="task.removal_decided", recipients__user=crew.mia).exists()
    base = f"/projects/{project['id']}/tasks"
    board = crew.pam_d.call("get", base).data
    assert [t["id"] for c in board["columns"] for t in c["tasks"]] == [keep["id"]]
    for view in ("list",):
        assert [t["id"] for t in crew.mia_d.call("get", f"{base}?view={view}").data["tasks"]] == [keep["id"]]
    soon, later = [(timezone.now() + timedelta(days=d)).strftime("%Y-%m-%dT%H:%M:%SZ") for d in (-1, 30)]
    cal = crew.pam_d.call("get", f"{base}?view=calendar&from={soon}&to={later}")
    assert cal.status_code == 200 and task["id"] not in [t["id"] for t in cal.data["tasks"]]
    cols = crew.pam_d.call("get", f"/projects/{project['id']}/columns").data
    assert sum(c["task_count"] for c in cols) == 1
    assert Project.objects.get(pk=project["id"]).progress == 100  # the removed task does not count
    assert ChangeHistory.objects.filter(subject=Task.objects.get(pk=task["id"]).subject, field="hidden").exists()


def test_hidden_tasks_are_visible_to_managers_only(crew, project, make_ptask):
    setting(crew, project, require_removal_approval=True)
    task = make_ptask()
    removal(crew.mia_d, task)
    decide(crew.pam_d, task)
    base = f"/projects/{project['id']}/tasks?view=list&include_hidden=true"
    assert [t["id"] for t in crew.pam_d.call("get", base).data["tasks"]] == [task["id"]]
    assert crew.mia_d.call("get", base).data["tasks"] == []  # the flag is ignored for non managers
    assert crew.pam_d.call("get", "/tasks").data == []
    assert [t["id"] for t in crew.pam_d.call("get", "/tasks?include_hidden=true").data] == [task["id"]]
    assert crew.mia_d.call("get", "/tasks?include_hidden=true").data == []
    assert crew.pam_d.call("get", f"/tasks/{task['id']}").status_code == 200
    assert crew.mia_d.call("get", f"/tasks/{task['id']}").status_code == 404
    sid = task["subject_id"]
    assert crew.mia_d.call("get", f"/subjects/{sid}/comments").status_code == 404
    assert crew.pam_d.call("get", f"/subjects/{sid}/comments").status_code == 200


def test_rejection_keeps_the_task_and_allows_a_new_request(crew, project, make_ptask):
    setting(crew, project, require_removal_approval=True)
    task = make_ptask()
    removal(crew.mia_d, task)
    resp = decide(crew.pam_d, task, "reject", "still needed")
    assert resp.data["status"] == "open" and resp.data["hidden"] is False
    assert resp.data["removal"]["status"] == "rejected"
    assert crew.mia_d.call("get", f"/tasks/{task['id']}").data["removal"]["decision_note"] == "still needed"
    assert removal(crew.mia_d, task).status_code == 200
    assert RemovalRequest.objects.filter(task_id=task["id"]).count() == 2


def test_manager_reopen_unhides(crew, project, make_ptask):
    setting(crew, project, require_removal_approval=True)
    task = make_ptask()
    removal(crew.mia_d, task)
    decide(crew.pam_d, task)
    resp = crew.pam_d.call("post", f"/tasks/{task['id']}/reopen")
    assert resp.status_code == 200 and resp.data["hidden"] is False and resp.data["status"] == "open"
    assert crew.mia_d.call("get", f"/tasks/{task['id']}").status_code == 200


def test_removal_requires_a_project_task(team, make_task):
    task = make_task()
    assert team.cat_d.call("post", f"/tasks/{task['id']}/removal-request", {"note": "x"}).status_code == 403
    assert team.cat_d.call("post", f"/tasks/{task['id']}/removal-decision", {"decision": "approve"}).status_code == 403
