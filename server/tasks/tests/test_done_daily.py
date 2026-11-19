from datetime import timedelta

from django.utils import timezone

from tasks.models import TaskPerson
from workspace.models import ChangeHistory
from workspace.recurrence import TEHRAN


def today() -> str:
    return timezone.now().astimezone(TEHRAN).date().isoformat()


def done_list(who, day=None):
    resp = who.call("get", f"/tasks/done-daily?date={day or today()}")
    assert resp.status_code == 200, resp.content
    return resp.data


def test_owner_completion_is_listed_with_time(team, make_task):
    task = make_task(title="Write report")
    other = make_task(title="Still open")
    assert team.olga_d.call("post", f"/tasks/{task['id']}/complete").status_code == 200
    data = done_list(team.olga_d)
    assert data["date"] == today() and data["total"] == 1
    assert set(data["groups"]) == {"completed", "submitted", "approved", "rejected"}
    [item] = data["groups"]["completed"]
    assert (item["task_id"], item["title"], item["project_name"]) == (task["id"], "Write report", "")
    assert item["at"].endswith("Z") and other["id"] not in str(data)
    assert done_list(team.cat_d)["total"] == 0  # the creator did not complete it
    assert done_list(team.out_d)["total"] == 0


def test_approval_flow_groups_owner_and_approver_actions(team, approved_flow):
    tid = approved_flow["id"]
    team.olga_d.call("post", f"/tasks/{tid}/complete")
    team.abe_d.call("post", f"/tasks/{tid}/decision", {"decision": "approve"})
    team.ben_d.call("post", f"/tasks/{tid}/decision", {"decision": "approve"})
    assert [i["task_id"] for i in done_list(team.olga_d)["groups"]["submitted"]] == [tid]
    assert done_list(team.olga_d)["groups"]["completed"] == []
    abe = done_list(team.abe_d)["groups"]
    assert [i["task_id"] for i in abe["approved"]] == [tid] and abe["completed"] == []
    ben = done_list(team.ben_d)["groups"]
    assert [i["task_id"] for i in ben["approved"]] == [tid] and [i["task_id"] for i in ben["completed"]] == [tid]


def test_rejection_is_listed_for_the_approver(team, approved_flow):
    tid = approved_flow["id"]
    team.olga_d.call("post", f"/tasks/{tid}/complete")
    team.abe_d.call("post", f"/tasks/{tid}/decision", {"decision": "reject", "note": "redo"})
    assert [i["task_id"] for i in done_list(team.abe_d)["groups"]["rejected"]] == [tid]


def test_day_is_the_tehran_local_date(team, make_task):
    task = make_task()
    team.olga_d.call("post", f"/tasks/{task['id']}/complete")
    at = ChangeHistory.objects.get(field="status", new="done").at
    local = at.astimezone(TEHRAN).date()
    assert done_list(team.olga_d, local.isoformat())["total"] == 1
    for other in (local - timedelta(days=1), local + timedelta(days=1)):
        assert done_list(team.olga_d, other.isoformat())["total"] == 0


def test_tasks_the_user_lost_access_to_are_skipped_and_bad_date_rejected(team, make_task):
    task = make_task()
    team.olga_d.call("post", f"/tasks/{task['id']}/complete")
    TaskPerson.objects.filter(task_id=task["id"], user=team.olga).update(active=False)  # she was removed
    assert done_list(team.olga_d)["total"] == 0
    assert team.olga_d.call("get", "/tasks/done-daily?date=nope").status_code == 422
    assert done_list_default(team)["total"] == 0


def done_list_default(team):
    resp = team.olga_d.call("get", "/tasks/done-daily")
    assert resp.status_code == 200
    return resp.data
