import pytest
from django.utils import timezone

from tasks.models import Task

ENDPOINTS = ["/monitor/overview", "/monitor/projects", "/monitor/tasks", "/monitor/meetings", "/monitor/members",
             "/monitor/online", "/monitor/customers", "/monitor/finance", "/monitor/sales"]


@pytest.mark.parametrize("path", ENDPOINTS)
def test_non_holder_gets_404(crew, path):
    assert crew.pam_d.call("get", path).status_code == 404


@pytest.mark.parametrize("path", ENDPOINTS)
def test_company_manager_without_grant_gets_404(crew, path):
    assert crew.boss.call("get", path).status_code == 404


def test_me_is_open_to_everyone(crew, make_ptask):
    make_ptask()
    resp = crew.mia_d.call("get", "/monitor/me?period=week")
    assert resp.status_code == 200
    assert resp.data["tasks"]["open"] == 1


def test_me_rejects_unknown_period(crew):
    assert crew.mia_d.call("get", "/monitor/me?period=decade").status_code == 422


def test_overview_has_enabled_module_blocks_with_month_buckets(watcher, make_ptask):
    make_ptask()
    resp = watcher.call("get", "/monitor/overview?period=year&bucket=month&calendar=jalali")
    assert resp.status_code == 200
    mods = resp.data["modules"]
    assert {"tasks", "letters", "meetings", "crm", "chat", "projects"} <= set(mods)
    assert sum(p["value"] for p in mods["tasks"]["series"]["created"]) == 1
    assert len(mods["tasks"]["series"]["created"]) <= 14


def test_overview_omits_disabled_modules(watcher, brand_dir):
    brand_dir(modules=["tasks"])
    mods = watcher.call("get", "/monitor/overview").data["modules"]
    assert list(mods) == ["tasks"]


def test_disabled_module_endpoint_is_404(watcher, brand_dir):
    brand_dir(modules=["tasks"])
    assert watcher.call("get", "/monitor/customers").status_code == 404


def test_tasks_report_lists_overdue_with_who_and_how_late(crew, watcher, project, overdue_task):
    resp = watcher.call("get", f"/monitor/tasks?project={project['id']}&person={crew.mia.id}")
    assert resp.status_code == 200
    assert resp.data["overdue_total"] == 1
    row = resp.data["overdue"][0]
    assert row["title"] == "Build page" and row["days_late"] >= 2
    assert row["owners"][0]["id"] == crew.mia.id
    assert "description" not in row


def test_tasks_report_person_filter_excludes_others(crew, watcher, overdue_task):
    resp = watcher.call("get", f"/monitor/tasks?person={crew.mel.id}")
    assert resp.data["overdue_total"] == 0


def test_tasks_report_invalid_project_filter_is_422(watcher):
    assert watcher.call("get", "/monitor/tasks?project=not-a-uuid").status_code == 422


def test_tasks_printable_returns_everything(watcher, overdue_task):
    resp = watcher.call("get", "/monitor/tasks?printable=true&limit=0")
    assert resp.data["printable"] is True and len(resp.data["overdue"]) == 1


def test_projects_sort_by_most_overdue(crew, watcher, project, overdue_task):
    resp = watcher.call("get", "/monitor/projects?sort=most_overdue")
    assert resp.status_code == 200
    assert resp.data["projects"][0]["tasks_overdue"] == 1
    assert resp.data["groups"][0]["tasks_overdue"] == 1
    assert watcher.call("get", "/monitor/projects?sort=bogus").status_code == 422


def test_projects_last_done_reflects_completed_task(crew, watcher, project, make_ptask):
    data = make_ptask()
    Task.objects.filter(pk=data["id"]).update(status=Task.DONE, completed_at=timezone.now())
    row = watcher.call("get", "/monitor/projects?sort=completed").data["projects"][0]
    assert row["tasks_done"] == 1 and row["last_done_at"]


def test_meetings_filter_by_project_title(crew, watcher, project):
    from meetings.models import Meeting
    from workspace.models import Subject

    for title, proj in (("A", project["id"]), ("B", None)):
        Meeting.objects.create(subject=Subject.objects.create(module="meetings", kind="meeting"), title=title,
                               status=Meeting.SCHEDULED, starts_at=timezone.now(), creator=crew.pam,
                               project_id=proj)
    resp = watcher.call("get", "/monitor/meetings?project=web")
    assert resp.status_code == 200
    assert [m["title"] for m in resp.data["meetings"]] == ["A"]
    assert watcher.call("get", "/monitor/meetings").data["total"] == 2


def test_members_and_online(crew, watcher):
    members = watcher.call("get", "/monitor/members?sort=done").data
    assert members["total"] >= 6 and "tasks" in members["members"][0]
    online = watcher.call("get", f"/monitor/online?history_of={crew.pam.id}").data
    assert any(u["online"] for u in online["users"]) and online["history"]


def test_customers_report(crew, watcher):
    from crm.models import Customer
    from workspace.models import Subject

    Customer.objects.create(subject=Subject.objects.create(module="crm", kind="customer"), name="ACME", owner=crew.pam)
    data = watcher.call("get", "/monitor/customers").data
    assert data["total"] == 1 and data["customers"][0]["name"] == "ACME" and data["quiet"] == 1


def test_finance_and_sales_need_their_own_permission(watcher):
    assert watcher.call("get", "/monitor/finance").status_code == 404
    assert watcher.call("get", "/monitor/sales").status_code == 404


def test_finance_and_sales_for_double_holder(make_user, login, brand_dir):
    user = make_user("cfo@corp.test", grants=("monitor.view", "finance.manage", "sales.manage"))
    me = login(user)
    fin = me.call("get", "/monitor/finance?period=year&calendar=jalali")
    assert fin.status_code == 200 and "totals" in fin.data
    assert "by_status" in me.call("get", "/monitor/sales").data
    brand_dir(modules=["tasks"])
    assert me.call("get", "/monitor/finance").status_code == 404


def test_finance_holder_without_monitor_view_gets_404(make_user, login):
    me = login(make_user("fin@corp.test", grants=("finance.manage",)))
    assert me.call("get", "/monitor/finance").status_code == 404


def test_holder_reads_colleague_inbox_others_get_403(crew, watcher, make_ptask):
    make_ptask()
    ok = watcher.call("get", f"/tasks/of/{crew.mia.id}")
    assert ok.status_code == 200 and len(ok.data) == 1
    assert crew.pam_d.call("get", f"/tasks/of/{crew.mia.id}").status_code == 403
