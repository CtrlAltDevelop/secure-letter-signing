from datetime import date

import pytest

from workspace import jalali
from workspace.models import Holiday

RANGE = "from=2030-03-01T00:00:00Z&to=2030-03-31T00:00:00Z"


@pytest.fixture(autouse=True)
def _modules(brand_dir):
    brand_dir()


@pytest.fixture
def crew(make_user, login, manager):
    crew = type("Crew", (), {})()
    crew.manager, crew.boss = manager, login(manager)
    for name, grants in (("ann", ("task.create", "project.create")), ("bob", ("task.create", "project.create")),
                         ("mon", ("task.create", "monitor.view")), ("out", ())):
        user = make_user(f"{name}@corp.test", grants=grants)
        setattr(crew, name, user)
        setattr(crew, f"{name}_d", login(user))
    return crew


def make_task(who, **over):
    body = {"title": "T", "due_at": "2030-03-10T09:00:00Z", **over}
    resp = who.call("post", "/tasks", body)
    assert resp.status_code == 201, resp.content
    return resp.data


def items(who, query=RANGE):
    resp = who.call("get", f"/calendar?{query}")
    assert resp.status_code == 200, resp.content
    return resp.data


def test_items_have_the_documented_shape_and_default_weekend(crew):
    task = make_task(crew.ann_d, title="Report", start_at="2030-03-09T09:00:00Z")
    data = items(crew.ann_d)
    assert data["weekend"] == [5]
    [item] = data["items"]
    assert item == {"kind": "task", "id": task["id"], "subject_id": task["subject_id"], "title": "Report",
                    "start": "2030-03-09T09:00:00Z", "end": "2030-03-10T09:00:00Z", "all_day": False,
                    "status": "open", "project_id": None, "project_name": "", "color": 0, "done": False,
                    "owner_ids": None}


def test_only_visible_items_and_range_filter(crew):
    make_task(crew.ann_d, title="Mine")
    make_task(crew.ann_d, title="Outside range", due_at="2031-01-01T00:00:00Z")
    make_task(crew.bob_d, title="Bob private")
    assert [i["title"] for i in items(crew.ann_d)["items"]] == ["Mine"]
    assert items(crew.out_d)["items"] == []
    assert items(crew.boss)["items"] == []  # the manager sees nothing automatically


def test_range_validation(crew):
    assert crew.ann_d.call("get", "/calendar?from=2030-03-02T00:00:00Z&to=2030-03-01T00:00:00Z").status_code == 422
    assert crew.ann_d.call("get", "/calendar?from=2030-01-01T00:00:00Z&to=2030-06-01T00:00:00Z").status_code == 422
    assert crew.ann_d.call("get", f"/calendar?{RANGE}&kinds=bogus").status_code == 422
    assert crew.ann_d.call("get", "/calendar").status_code == 422


def test_kinds_meetings_reminders_projects_and_filters(crew):
    project = crew.ann_d.call("post", "/projects", {"name": "Site", "color": 3, "start_date": "2030-03-05",
                                                    "end_date": "2030-03-07",
                                                    "members": [{"user_id": crew.bob.id, "role": "member"}]}).data
    in_project = make_task(crew.ann_d, title="In project", project_id=project["id"])
    plain = make_task(crew.ann_d, title="Plain")
    meeting = crew.ann_d.call("post", "/meetings", {"title": "Sync", "starts_at": "2030-03-12T08:00:00Z",
                                                    "ends_at": "2030-03-12T09:00:00Z", "project_id": project["id"]})
    assert meeting.status_code == 201, meeting.content
    rem = crew.ann_d.call("post", f"/subjects/{plain['subject_id']}/reminders", {"at": "2030-03-11T06:00:00Z"})
    assert rem.status_code == 201, rem.content
    kinds = {i["kind"]: i for i in items(crew.ann_d)["items"]}
    assert set(kinds) == {"task", "meeting", "reminder", "project"}
    assert kinds["project"]["all_day"] and kinds["project"]["color"] == 3
    assert kinds["project"]["start"] == "2030-03-04T20:30:00Z"  # 5 Mar 00:00 Tehran (+03:30)
    assert kinds["meeting"]["project_name"] == "Site" and kinds["meeting"]["end"] == "2030-03-12T09:00:00Z"
    only = items(crew.ann_d, f"{RANGE}&kinds=meeting,reminder")["items"]
    assert sorted(i["kind"] for i in only) == ["meeting", "reminder"]
    scoped = items(crew.ann_d, f"{RANGE}&project={project['id']}")["items"]
    assert sorted(i["kind"] for i in scoped) == ["meeting", "project", "task"]
    assert [i["id"] for i in scoped if i["kind"] == "task"] == [in_project["id"]]
    assert "reminder" not in {i["kind"] for i in items(crew.bob_d)["items"]}  # reminders are mine only
    assert {i["title"] for i in items(crew.bob_d)["items"]} >= {"In project", "Site"}


def test_label_owner_and_customer_filters(crew):
    labelled = make_task(crew.ann_d, title="Labelled")
    other = make_task(crew.ann_d, title="Bobs", owner_ids=[crew.bob.id])
    label = crew.ann_d.call("post", "/labels", {"name": "hot", "scope": "personal"}).data
    crew.ann_d.call("put", f"/subjects/{labelled['subject_id']}/labels", {"label_ids": [label["id"]]})
    assert [i["title"] for i in items(crew.ann_d, f"{RANGE}&label={label['id']}")["items"]] == ["Labelled"]
    assert [i["id"] for i in items(crew.ann_d, f"{RANGE}&owner={crew.bob.id}")["items"]] == [other["id"]]
    assert items(crew.ann_d, f"{RANGE}&customer=00000000-0000-0000-0000-000000000000")["items"] == []


def test_switched_off_modules_are_skipped(crew, brand_dir):
    make_task(crew.ann_d)
    brand_dir(modules=["letters", "projects"])
    assert items(crew.ann_d)["items"] == []


def test_cancelled_tasks_are_hidden_and_done_flag_is_set(crew):
    done = make_task(crew.ann_d, title="Done one")
    gone = make_task(crew.ann_d, title="Gone")
    assert crew.ann_d.call("post", f"/tasks/{done['id']}/complete").status_code == 200
    assert crew.ann_d.call("post", f"/tasks/{gone['id']}/cancel").status_code == 200
    [item] = items(crew.ann_d)["items"]
    assert item["title"] == "Done one" and item["done"] is True


def test_calendar_includes_holidays_in_range(crew):
    Holiday.objects.create(date=date(2030, 3, 5), title="Day off", kind="company")
    Holiday.objects.create(date=date(2030, 3, 6), title="Hidden", kind="company", active=False)
    Holiday.objects.create(date=date(2030, 4, 20), title="Later", kind="company")
    [h] = items(crew.ann_d)["holidays"]
    assert (h["date"], h["title"], h["kind"]) == ("2030-03-05", "Day off", "company")


# --- holidays ---------------------------------------------------------------------------------------------------

def test_holiday_list_and_manager_only_writes(crew):
    row = crew.boss.call("post", "/holidays", {"date": "2030-03-05", "title": "Founders day", "kind": "company"})
    assert row.status_code == 201 and row.data["active"] is True
    assert crew.ann_d.call("post", "/holidays", {"date": "2030-03-06", "title": "x"}).status_code == 403
    assert crew.boss.call("post", "/holidays", {"date": "2030-03-05", "title": "Founders day"}).status_code == 409
    assert [h["title"] for h in crew.ann_d.call("get", "/holidays?from=2030-03-01&to=2030-03-31").data] == [
        "Founders day"]
    assert crew.ann_d.call("patch", f"/holidays/{row.data['id']}", {"active": False}).status_code == 403
    assert crew.boss.call("patch", f"/holidays/{row.data['id']}", {"active": False}).data["active"] is False
    assert crew.ann_d.call("get", "/holidays?from=2030-03-01&to=2030-03-31").data == []
    assert len(crew.boss.call("get", "/holidays?from=2030-03-01&to=2030-03-31&include_inactive=true").data) == 1
    assert Holiday.objects.count() == 1  # deactivated, never deleted
    assert crew.ann_d.call("get", "/holidays?from=2030-03-31&to=2030-03-01").status_code == 422


def test_reposting_an_inactive_holiday_reactivates_it(crew):
    row = crew.boss.call("post", "/holidays", {"date": "2030-03-05", "title": "A"}).data
    crew.boss.call("patch", f"/holidays/{row['id']}", {"active": False})
    again = crew.boss.call("post", "/holidays", {"date": "2030-03-05", "title": "A", "kind": "religious"})
    assert again.status_code == 201 and again.data["active"] and again.data["kind"] == "religious"


def test_load_holidays_seeds_fixed_days_idempotently(db):
    from django.core.management import call_command

    call_command("load_holidays", "--from-year", "1405", "--to-year", "1406")
    assert Holiday.objects.count() == 20
    assert Holiday.objects.filter(date=jalali.to_gregorian(1405, 1, 1)).exists()
    assert Holiday.objects.filter(date=jalali.to_gregorian(1406, 12, 29)).exists()
    assert set(Holiday.objects.values_list("kind", flat=True)) == {"official"}
    call_command("load_holidays", "--from-year", "1405", "--to-year", "1405")
    assert Holiday.objects.count() == 20


def test_load_holidays_rejects_a_bad_range(db):
    from django.core.management import CommandError, call_command

    with pytest.raises(CommandError):
        call_command("load_holidays", "--from-year", "1406", "--to-year", "1405")


# --- monitor.view ------------------------------------------------------------------------------------------------

def test_monitor_permission_is_seeded_and_granted_to_nobody(db):
    from accounts.models import Permission

    assert Permission.objects.get(code="monitor.view").users.count() == 0


def test_team_calendar_for_holders_only_without_content(crew):
    secret = crew.ann_d.call("post", "/tasks", {"title": "Ann task", "due_at": "2030-03-10T09:00:00Z",
                                                "description": {"text": "TOP SECRET"}}).data
    crew.ann_d.call("post", f"/subjects/{secret['subject_id']}/comments", {"body": {"text": "private chatter"}})
    make_task(crew.bob_d, title="Bob task")
    assert crew.ann_d.call("get", f"/calendar?{RANGE}&team=true").status_code == 403
    assert crew.boss.call("get", f"/calendar?{RANGE}&team=true").status_code == 403  # no manager override
    resp = crew.mon_d.call("get", f"/calendar?{RANGE}&team=true")
    assert resp.status_code == 200
    assert sorted(i["title"] for i in resp.data["items"]) == ["Ann task", "Bob task"]
    raw = resp.content.decode()
    assert "TOP SECRET" not in raw and "private chatter" not in raw and "description" not in raw
    only = crew.mon_d.call("get", f"/calendar?{RANGE}&team=true&user={crew.bob.id}").data["items"]
    assert [i["title"] for i in only] == ["Bob task"] and only[0]["owner_ids"] == [crew.bob.id]
    # holding the permission opens no detail view
    assert crew.mon_d.call("get", f"/tasks/{secret['id']}").status_code == 404
    assert crew.mon_d.call("get", f"/subjects/{secret['subject_id']}/comments").status_code == 404


def test_tasks_of_returns_briefs_for_holders_only(crew):
    t = crew.ann_d.call("post", "/tasks", {"title": "Ann inbox", "description": {"text": "TOP SECRET"},
                                           "owner_ids": [crew.ann.id], "follower_ids": [crew.bob.id]}).data
    crew.bob_d.call("post", "/tasks", {"title": "Bob delegated", "owner_ids": [crew.ann.id]})
    done = make_task(crew.ann_d, title="Finished")
    crew.ann_d.call("post", f"/tasks/{done['id']}/complete")
    url = f"/tasks/of/{crew.ann.id}"
    assert crew.ann_d.call("get", f"{url}?box=inbox").status_code == 403
    assert crew.boss.call("get", f"{url}?box=inbox").status_code == 403
    inbox = crew.mon_d.call("get", f"{url}?box=inbox")
    assert inbox.status_code == 200
    assert sorted(b["title"] for b in inbox.data) == ["Ann inbox", "Bob delegated"]
    assert "TOP SECRET" not in inbox.content.decode() and "description" not in inbox.data[0]
    assert all(b["my_roles"] == [] and b["label_ids"] == [] for b in inbox.data)
    assert crew.mon_d.call("get", f"{url}?box=followup").data == []  # Finished is done, the others are owned
    assert crew.mon_d.call("get", f"{url}?box=all").status_code == 422
    assert crew.mon_d.call("get", "/tasks/of/99999?box=inbox").status_code == 404
    assert len(crew.mon_d.call("get", f"{url}?box=inbox&limit=1").data) == 1
    assert t["id"] in [b["id"] for b in crew.mon_d.call("get", f"/tasks/of/{crew.bob.id}?box=followup").data]
