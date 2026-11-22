import pytest
from projects.tests.conftest import *  # noqa: F401,F403  (crew, project, make_ptask, ...)

from accounts.models import AuditEvent, Notification
from gantt.models import GanttItem
from workspace.models import ChangeHistory, Event


def g(project, tail=""):
    return f"/projects/{project['id']}/gantt{tail}"


@pytest.fixture
def three(make_ptask):
    return [make_ptask(title=t) for t in ("Design", "Build", "Ship")]


def put_item(who, project, task, **body):
    return who.call("put", g(project, f"/items/{task['id']}"), body)


def test_chart_requires_membership_and_module(crew, project, brand_dir):
    assert crew.vic_d.call("get", g(project)).status_code == 200
    assert crew.out_d.call("get", g(project)).status_code == 404
    brand_dir(modules=["tasks", "projects"])
    assert crew.pam_d.call("get", g(project)).status_code == 404


def test_roles_viewer_reads_manager_edits_member_follows_setting(crew, project, three):
    body = {"title": "Phase"}
    assert crew.vic_d.call("post", g(project, "/phases"), body).status_code == 403
    assert crew.out_d.call("post", g(project, "/phases"), body).status_code == 404
    assert crew.pam_d.call("post", g(project, "/phases"), body).status_code == 201
    assert crew.mia_d.call("post", g(project, "/phases"), body).status_code == 201  # members_can_edit_tasks default
    assert crew.vic_d.call("get", g(project)).data["can_edit"] is False
    assert put_item(crew.vic_d, project, three[0]).status_code == 403
    assert crew.pam_d.call("patch", f"/projects/{project['id']}", {"members_can_edit_tasks": False}).status_code == 200
    assert crew.mia_d.call("post", g(project, "/phases"), body).status_code == 403
    assert crew.mia_d.call("get", g(project)).data["can_edit"] is False
    assert put_item(crew.pam_d, project, three[0]).status_code == 200


def test_phases_wbs_dates_and_progress(crew, project, three):
    p1 = crew.pam_d.call("post", g(project, "/phases"), {"title": "  Plan  "}).data
    p2 = crew.pam_d.call("post", g(project, "/phases"), {"title": "Deliver", "start_at": "2026-02-01", "end_at": "2026-02-10"}).data
    assert (p1["title"], p1["wbs"], p2["wbs"]) == ("Plan", "1", "2")
    assert crew.pam_d.call("post", g(project, "/phases"), {"title": "x", "start_at": "2026-02-02", "end_at": "2026-02-01"}).status_code == 422
    put_item(crew.pam_d, project, three[0], phase_id=p1["id"], start_at="2026-01-05", end_at="2026-01-09")
    put_item(crew.pam_d, project, three[1], phase_id=p1["id"], start_at="2026-01-10", end_at="2026-01-20")
    put_item(crew.pam_d, project, three[2], parent_task_id=three[1]["id"], start_at="2026-01-12", end_at="2026-01-15")
    crew.mia_d.call("post", f"/tasks/{three[0]['id']}/complete")
    chart = crew.vic_d.call("get", g(project)).data
    assert [(i["title"], i["wbs"], i["level"], i["phase_id"]) for i in chart["items"]] == [
        ("Design", "1.1", 2, p1["id"]), ("Build", "1.2", 2, p1["id"]), ("Ship", "1.2.1", 3, p1["id"])]
    assert chart["items"][2]["parent_task_id"] == three[1]["id"]
    ph = {p["id"]: p for p in chart["phases"]}
    assert (ph[p1["id"]]["start"], ph[p1["id"]]["end"], ph[p1["id"]]["task_count"]) == ("2026-01-05", "2026-01-20", 3)
    assert ph[p1["id"]]["start_at"] is None and ph[p2["id"]]["start"] == "2026-02-01"
    assert chart["items"][0]["progress"] == 100 and ph[p1["id"]]["progress"] > 0
    assert (chart["start"], chart["end"], chart["unplanned"]) == ("2026-01-05", "2026-02-10", [])
    # explicit null clears an override, a missing key leaves it alone
    out = crew.pam_d.call("patch", g(project, f"/phases/{p2['id']}"), {"end_at": None}).data
    assert out["start_at"] == "2026-02-01" and out["end_at"] is None


def test_item_dates_fall_back_to_task_and_unplanned_lists_the_rest(crew, project, make_ptask):
    t = make_ptask(title="Dated", due_at="2026-03-10T12:00:00Z", start_at="2026-03-01T08:00:00Z")
    other = make_ptask(title="Loose")
    chart = crew.pam_d.call("get", g(project)).data
    assert {u["task_id"] for u in chart["unplanned"]} == {t["id"], other["id"]}
    item = put_item(crew.pam_d, project, t).data
    assert (item["start_at"], item["start"], item["end"], item["wbs"]) == (None, "2026-03-01", "2026-03-10", "1")
    assert put_item(crew.pam_d, project, t, start_at="2026-03-05", end_at="2026-03-04").status_code == 422
    assert [u["task_id"] for u in crew.pam_d.call("get", g(project)).data["unplanned"]] == [other["id"]]


def test_item_validation_and_nesting(crew, project, three, make_ptask):
    a, b, c = three
    other_project = crew.pam_d.call("post", "/projects", {"name": "Other", "members": []}).data
    foreign = crew.pam_d.call("post", "/tasks", {"title": "F", "project_id": other_project["id"], "owner_ids": [crew.pam.id]}).data
    assert put_item(crew.pam_d, project, foreign).status_code == 422
    assert put_item(crew.pam_d, project, a, phase_id=999).status_code == 422
    assert put_item(crew.pam_d, project, b, parent_task_id=a["id"]).status_code == 422  # parent not planned
    put_item(crew.pam_d, project, a)
    put_item(crew.pam_d, project, b, parent_task_id=a["id"])
    assert put_item(crew.pam_d, project, a, parent_task_id=b["id"]).status_code == 422  # cycle in the tree
    assert put_item(crew.pam_d, project, a, parent_task_id=a["id"]).status_code == 422
    phase = crew.pam_d.call("post", g(project, "/phases"), {"title": "P"}).data
    assert put_item(crew.pam_d, project, c, phase_id=phase["id"], parent_task_id=a["id"]).status_code == 422
    # a deactivated item hands its children upward and leaves the chart
    assert put_item(crew.pam_d, project, a, active=False).status_code == 200
    items = {i["title"]: i for i in crew.pam_d.call("get", g(project)).data["items"]}
    assert set(items) == {"Build"} and items["Build"]["parent_task_id"] is None and items["Build"]["wbs"] == "2"  # one phase exists
    assert GanttItem.objects.filter(task_id=a["id"], active=False).exists()  # never deleted


def test_deactivating_a_phase_keeps_its_tasks_at_top_level(crew, project, three):
    phase = crew.pam_d.call("post", g(project, "/phases"), {"title": "P"}).data
    put_item(crew.pam_d, project, three[0], phase_id=phase["id"])
    assert crew.pam_d.call("patch", g(project, f"/phases/{phase['id']}"), {"active": False}).status_code == 200
    chart = crew.pam_d.call("get", g(project)).data
    assert chart["phases"] == [] and chart["items"][0]["phase_id"] is None and chart["items"][0]["wbs"] == "1"
    assert crew.pam_d.call("patch", g(project, "/phases/999"), {"title": "x"}).status_code == 404


def test_links_validation_cycles_and_conflict_flag(crew, project, three):
    a, b, c = three
    link = lambda x, y: crew.pam_d.call("post", g(project, "/links"), {"predecessor_task_id": x["id"], "successor_task_id": y["id"]})  # noqa: E731
    put_item(crew.pam_d, project, a, start_at="2026-01-01", end_at="2026-01-10")
    put_item(crew.pam_d, project, b, start_at="2026-01-05", end_at="2026-01-12")
    first = link(a, b)
    assert first.status_code == 201 and first.data["conflict"] is True and first.data["kind"] == "fs"
    assert link(a, b).data["id"] == first.data["id"]  # idempotent
    assert link(a, a).status_code == 422
    assert link(b, a).status_code == 422  # direct cycle
    assert link(b, c).status_code == 201
    assert link(c, a).status_code == 422  # indirect cycle
    ghost = {"predecessor_task_id": a["id"], "successor_task_id": "7b4d0b3c-0000-4000-8000-000000000000"}
    assert crew.pam_d.call("post", g(project, "/links"), ghost).status_code == 422
    assert crew.vic_d.call("post", g(project, "/links"), {"predecessor_task_id": a["id"], "successor_task_id": c["id"]}).status_code == 403
    chart = crew.vic_d.call("get", g(project)).data
    assert len(chart["links"]) == 2 and {i["title"] for i in chart["items"]} == {"Design", "Build", "Ship"}
    # deactivate (never delete) and re-add after the cycle is gone
    assert crew.pam_d.call("post", g(project, f"/links/{first.data['id']}/deactivate")).status_code == 200
    assert len(crew.vic_d.call("get", g(project)).data["links"]) == 1
    assert link(b, a).status_code == 201  # a->b is off, so b->a is no cycle any more
    assert link(a, b).status_code == 422


def test_reorder_phases_and_items(crew, project, three):
    p1 = crew.pam_d.call("post", g(project, "/phases"), {"title": "One"}).data
    p2 = crew.pam_d.call("post", g(project, "/phases"), {"title": "Two"}).data
    for t in three[:2]:
        put_item(crew.pam_d, project, t, phase_id=p1["id"])
    reorder = lambda **b: crew.pam_d.call("post", g(project, "/reorder"), b)  # noqa: E731
    assert reorder(phase_ids=[p1["id"]]).status_code == 422
    out = reorder(phase_ids=[p2["id"], p1["id"]],
                  items=[{"task_id": three[1]["id"], "phase_id": p1["id"]}, {"task_id": three[0]["id"], "phase_id": p2["id"]}]).data
    assert [p["title"] for p in out["phases"]] == ["Two", "One"]
    assert [(i["title"], i["wbs"]) for i in out["items"]] == [("Design", "1.1"), ("Build", "2.1")]
    assert reorder(items=[{"task_id": three[2]["id"]}]).status_code == 422  # not in the plan
    assert reorder(items=[{"task_id": three[0]["id"]}, {"task_id": three[0]["id"]}]).status_code == 422
    assert crew.vic_d.call("post", g(project, "/reorder"), {"phase_ids": []}).status_code == 403


def test_print_data_is_flat_and_complete(crew, project, three):
    phase = crew.pam_d.call("post", g(project, "/phases"), {"title": "Plan"}).data
    put_item(crew.pam_d, project, three[0], phase_id=phase["id"], start_at="2026-01-05", end_at="2026-01-09")
    put_item(crew.pam_d, project, three[1], start_at="2026-01-10", end_at="2026-01-12")
    crew.pam_d.call("post", g(project, "/links"), {"predecessor_task_id": three[0]["id"], "successor_task_id": three[1]["id"]})
    out = crew.vic_d.call("get", g(project, "/print"))
    assert out.status_code == 200
    d = out.data
    assert [(r["kind"], r["wbs"], r["title"]) for r in d["rows"]] == [("phase", "1", "Plan"), ("task", "1.1", "Design"), ("task", "2", "Build")]
    assert (d["start"], d["end"], d["days"], d["weekend"]) == ("2026-01-05", "2026-01-12", 8, [5])
    assert d["links"] == [{"from_wbs": "1.1", "to_wbs": "2", "conflict": False}] and d["name"] == "Website"
    assert d["rows"][1]["owners"] and crew.out_d.call("get", g(project, "/print")).status_code == 404


def test_owners_are_told_once_when_all_prerequisites_are_done(crew, project, make_ptask):
    a, b = make_ptask(title="A"), make_ptask(title="B")
    c = make_ptask(title="C", owner_ids=[crew.mel.id])
    for pred in (a, b):
        crew.pam_d.call("post", g(project, "/links"), {"predecessor_task_id": pred["id"], "successor_task_id": c["id"]})
    mel = lambda: Notification.objects.filter(user=crew.mel, kind="gantt.task_ready")  # noqa: E731
    crew.mia_d.call("post", f"/tasks/{a['id']}/complete")
    assert mel().count() == 0
    crew.mia_d.call("post", f"/tasks/{b['id']}/complete")
    assert mel().count() == 1 and mel().first().title == "C"
    ev = Event.objects.get(kind="gantt.task_ready")
    assert ev.module == "gantt" and list(ev.recipients.values_list("user_id", flat=True)) == [crew.mel.id]
    from tasks.models import Task
    Task.objects.get(pk=a["id"]).save()  # another save of a done prerequisite does not repeat it
    assert mel().count() == 1


def test_changes_are_logged_with_ids_only(crew, project, three):
    crew.pam_d.call("post", g(project, "/phases"), {"title": "Secret phase name"})
    assert ChangeHistory.objects.filter(subject__project__pk=project["id"], field="gantt.phase_created").count() == 1
    assert AuditEvent.objects.filter(action="gantt_phase_created").exists()
    assert all("Secret phase" not in str(e.data) for e in AuditEvent.objects.all())
    assert Event.objects.filter(module="gantt", kind="gantt.updated").exists()


def test_critical_path_marks_the_longest_chain_with_slack(crew, project, three):
    a, b, c = three
    put_item(crew.pam_d, project, a, start_at="2026-01-01", end_at="2026-01-05")  # 5 days
    put_item(crew.pam_d, project, b, start_at="2026-01-06", end_at="2026-01-15")  # 10 days
    put_item(crew.pam_d, project, c, start_at="2026-01-06", end_at="2026-01-07")  # 2 days
    for x, y in ((a, b), (a, c)):
        crew.pam_d.call("post", g(project, "/links"), {"predecessor_task_id": x["id"], "successor_task_id": y["id"]})
    items = {i["title"]: i for i in crew.vic_d.call("get", g(project)).data["items"]}
    assert [(items[t]["critical"], items[t]["slack"]) for t in ("Design", "Build", "Ship")] == [(True, 0), (True, 0), (False, 8)]
    rows = {r["title"]: r["critical"] for r in crew.vic_d.call("get", g(project, "/print")).data["rows"] if r["kind"] == "task"}
    assert rows == {"Design": True, "Build": True, "Ship": False}


def test_critical_path_ignores_unlinked_items_and_cycles():
    from gantt.critical import slack
    assert slack({"x": 3}, []) == {}
    assert slack({"p": 1, "q": 1}, [("p", "q"), ("q", "p")]) == {}


def test_gantt_tables_refuse_delete(db, crew, project, three):
    from django.db import DatabaseError, connection
    from gantt.models import GanttPhase
    crew.pam_d.call("post", g(project, "/phases"), {"title": "Plan"})
    with pytest.raises(DatabaseError), connection.cursor() as cur:
        cur.execute(f"DELETE FROM {GanttPhase._meta.db_table}")
    assert GanttPhase.objects.count() == 1
