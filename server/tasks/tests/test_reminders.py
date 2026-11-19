from datetime import timedelta

import pytest
from django.utils import timezone

from accounts.models import Notification
from workspace import registry
from workspace.models import Event, Reminder
from workspace.reminders import fire_due_reminders
from workspace.recurrence import TEHRAN


@pytest.fixture
def task(make_task):
    return make_task(title="Sign the contract")


def when(**delta):
    return (timezone.now() + timedelta(**delta)).isoformat()


def add(who, task, **body):
    return who.call("post", f"/subjects/{task['subject_id']}/reminders", body)


def due(reminder, minutes=1):
    Reminder.objects.filter(pk=reminder["id"]).update(next_at=timezone.now() - timedelta(minutes=minutes))


# --- endpoints ------------------------------------------------------------------------------------------------


def test_create_list_and_deactivate(team, task):
    resp = add(team.olga_d, task, at=when(hours=2))
    assert resp.status_code == 201 and resp.data["rule"] is None
    listed = team.olga_d.call("get", f"/subjects/{task['subject_id']}/reminders").data
    assert [r["id"] for r in listed] == [resp.data["id"]]
    assert team.olga_d.call("delete", f"/reminders/{resp.data['id']}").status_code == 204
    assert team.olga_d.call("get", f"/subjects/{task['subject_id']}/reminders").data == []
    assert Reminder.objects.get(pk=resp.data["id"]).active is False  # kept, not deleted


def test_reminders_are_private_to_their_owner(team, task):
    mine = add(team.olga_d, task, at=when(hours=2)).data
    assert team.cat_d.call("get", f"/subjects/{task['subject_id']}/reminders").data == []
    assert team.cat_d.call("delete", f"/reminders/{mine['id']}").status_code == 404
    assert team.boss.call("delete", f"/reminders/{mine['id']}").status_code == 404
    assert Reminder.objects.get(pk=mine["id"]).active is True


def test_cannot_remind_on_invisible_subject(team, task):
    assert add(team.out_d, task, at=when(hours=2)).status_code == 404
    assert team.out_d.call("get", f"/subjects/{task['subject_id']}/reminders").status_code == 404


def test_module_off_is_404(team, task, brand_dir):
    brand_dir(modules=["letters"])
    assert add(team.olga_d, task, at=when(hours=2)).status_code == 404


def test_rule_is_validated_and_completed(team, task):
    ok = add(team.olga_d, task, at=when(hours=2), rule={"freq": "monthly_jalali"})
    assert ok.status_code == 201 and ok.data["rule"]["freq"] == "monthly_jalali" and 1 <= ok.data["rule"]["day"] <= 31
    weekly = add(team.olga_d, task, at=when(hours=2), rule={"freq": "weekly", "interval": 2})
    assert len(weekly.data["rule"]["weekdays"]) == 1
    for rule in ({"freq": "yearly"}, {"freq": "daily", "interval": 0}, {"freq": "weekly", "weekdays": [9]},
                 {"freq": "weekly", "weekdays": []}):
        assert add(team.olga_d, task, at=when(hours=2), rule=rule).status_code == 422


def test_past_or_naive_time_is_422(team, task):
    assert add(team.olga_d, task, at=when(hours=-1)).status_code == 422
    assert add(team.olga_d, task, at="2099-01-01T10:00:00").status_code == 422


# --- firing ---------------------------------------------------------------------------------------------------


def test_due_fires_future_does_not_and_title_comes_from_the_module(team, task):
    soon = add(team.olga_d, task, at=when(hours=1)).data
    later = add(team.olga_d, task, at=when(days=3)).data
    due(soon)
    assert fire_due_reminders() == 1
    note = Notification.objects.get(user=team.olga, kind="reminder")
    assert note.title == "Sign the contract"
    assert note.data == {"module": "tasks", "subject_id": task["subject_id"], "object_id": task["id"]}
    assert Reminder.objects.get(pk=later["id"]).last_fired_at is None


def test_one_shot_is_deactivated_and_second_run_is_idempotent(team, task):
    r = add(team.olga_d, task, at=when(hours=1)).data
    due(r)
    assert fire_due_reminders() == 1
    row = Reminder.objects.get(pk=r["id"])
    assert row.active is False and row.last_fired_at is not None
    assert fire_due_reminders() == 0
    assert Notification.objects.filter(kind="reminder").count() == 1


def test_recurring_advances_past_now_and_fires_once(team, task):
    r = add(team.olga_d, task, at=when(hours=1), rule={"freq": "daily", "interval": 1}).data
    Reminder.objects.filter(pk=r["id"]).update(next_at=timezone.now() - timedelta(days=3, minutes=5))
    assert fire_due_reminders() == 1  # missed days are not replayed
    row = Reminder.objects.get(pk=r["id"])
    assert row.active is True and timezone.now() < row.next_at <= timezone.now() + timedelta(days=1, minutes=1)
    assert fire_due_reminders() == 0
    assert Notification.objects.filter(kind="reminder").count() == 1


def test_recurring_keeps_the_tehran_wall_time(team, task):
    r = add(team.olga_d, task, at=when(hours=1), rule={"freq": "weekly"}).data
    row = Reminder.objects.get(pk=r["id"])
    start = row.next_at.astimezone(TEHRAN)
    row.next_at = timezone.now() - timedelta(minutes=1)
    row.save()
    fire_due_reminders()
    after = Reminder.objects.get(pk=r["id"]).next_at.astimezone(TEHRAN)
    assert after > timezone.now() and (after.hour, after.minute) == (row.next_at.astimezone(TEHRAN).hour,
                                                                    row.next_at.astimezone(TEHRAN).minute)
    assert start is not None


def test_inactive_user_is_skipped(team, task):
    r = add(team.olga_d, task, at=when(hours=1)).data
    due(r)
    team.olga.is_active = False
    team.olga.save()
    assert fire_due_reminders() == 0
    assert Notification.objects.filter(kind="reminder").count() == 0
    assert Reminder.objects.get(pk=r["id"]).last_fired_at is None


def test_user_who_lost_access_gets_nothing_and_reminder_stops(team, task):
    r = add(team.olga_d, task, at=when(hours=1)).data
    assert team.cat_d.call("put", f"/tasks/{task['id']}/people", {"owner_ids": [team.cat.id]}).status_code == 200
    due(r)
    assert fire_due_reminders() == 0
    assert Notification.objects.filter(kind="reminder").count() == 0
    assert Reminder.objects.get(pk=r["id"]).active is False


def test_module_off_stops_reminding(team, task, brand_dir):
    r = add(team.olga_d, task, at=when(hours=1)).data
    due(r)
    brand_dir(modules=["letters"])
    assert fire_due_reminders() == 0 and Reminder.objects.get(pk=r["id"]).active is False


def test_run_reminders_command_once(team, task):
    from django.core.management import call_command

    r = add(team.olga_d, task, at=when(hours=1)).data
    due(r)
    call_command("run_reminders", "--once")
    assert Notification.objects.filter(kind="reminder").count() == 1


# --- titles on comment/file events -------------------------------------------------------------------------------


def test_comment_event_carries_the_object_title(team, task):
    resp = team.olga_d.call("post", f"/subjects/{task['subject_id']}/comments", {"body": {"text": "hello"}})
    assert resp.status_code == 201
    assert Event.objects.get(kind="comment.created").title == "Sign the contract"


def test_modules_without_title_keep_an_empty_title(dummy, make_user, login):
    ann = make_user("ann@corp.test")
    subject = dummy.add(edit=[ann])
    assert login(ann).call("post", f"/subjects/{subject.id}/comments", {"body": {"text": "x"}}).status_code == 201
    assert registry.get("dummy").title is None
    assert Event.objects.get(kind="comment.created").title == ""
