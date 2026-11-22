from datetime import date, timedelta

import pytest
from django.core import mail
from django.core.files.uploadedfile import SimpleUploadedFile
from django.core.management import call_command
from django.utils import timezone as dj_tz

from accounts import daily, notify as notify_module
from accounts.models import DailyRun, Notification, UserPrefs
from workspace import jalali

PNG = b"\x89PNG\r\n\x1a\n" + b"0" * 64
JPEG = b"\xff\xd8\xff\xe0" + b"1" * 64
WEBP = b"RIFF\x10\x00\x00\x00WEBPVP8 " + b"2" * 32


@pytest.fixture
def me(make_user, api):
    user = make_user("me@corp.test")
    token = api.login(user.email)["access"]
    return type("Me", (), {"user": user, "call": lambda self, m, p, d=None: api.call(m, p, d, token=token),
                           "token": token, "client": api.client})()


def test_prefs_default_and_patch(me):
    first = me.call("get", "/me/prefs")
    assert first.status_code == 200 and first.data == {
        "theme": "auto", "birthday": None, "birthday_visible": True, "dnd_until": None, "personal_email": "",
        "personal_email_verified": False, "has_background": False}
    assert UserPrefs.objects.count() == 1  # created lazily, once
    resp = me.call("patch", "/me/prefs", {"theme": "dark", "birthday": "1990-05-17", "birthday_visible": False})
    assert resp.status_code == 200 and resp.data["theme"] == "dark" and resp.data["birthday"] == "1990-05-17"
    assert resp.data["birthday_visible"] is False
    assert me.call("patch", "/me/prefs", {"theme": "light"}).data["birthday"] == "1990-05-17"  # untouched
    assert me.call("patch", "/me/prefs", {"birthday": None}).data["birthday"] is None  # null clears
    assert me.call("patch", "/me/prefs", {"theme": "neon"}).status_code == 422
    assert me.call("patch", "/me/prefs", {"birthday": "2999-01-01"}).status_code == 422
    assert me.call("patch", "/me/prefs", {"birthday": "yesterday"}).status_code == 422


def test_prefs_need_login(api):
    assert api.call("get", "/me/prefs").status_code == 401


# --- do not disturb ------------------------------------------------------------------------------------------------

@pytest.fixture
def pushes(monkeypatch):
    calls = []
    monkeypatch.setattr(notify_module, "push", lambda user_id, event: calls.append((user_id, event["kind"])))
    return calls


def test_dnd_stores_but_does_not_push_or_email(me, make_user, pushes, django_capture_on_commit_callbacks):
    other = make_user("other@corp.test")
    me.call("patch", "/me/prefs", {"dnd_until": (dj_tz.now() + timedelta(hours=2)).isoformat()})
    with django_capture_on_commit_callbacks(execute=True):
        notify_module.notify([me.user, other], "task.assigned", "Report")
    assert Notification.objects.filter(user=me.user, kind="task.assigned").count() == 1  # stored
    assert pushes == [(other.id, "task.assigned")]  # only the other user was pushed
    assert [m.to for m in mail.outbox] == [[other.email]]


def test_expired_dnd_delivers_again(me, pushes, django_capture_on_commit_callbacks):
    UserPrefs.objects.create(user=me.user, dnd_until=dj_tz.now() - timedelta(minutes=1))
    with django_capture_on_commit_callbacks(execute=True):
        notify_module.notify([me.user], "task.assigned", "Report")
    assert pushes == [(me.user.id, "task.assigned")] and len(mail.outbox) == 1


def test_dnd_can_be_cleared(me):
    me.call("patch", "/me/prefs", {"dnd_until": (dj_tz.now() + timedelta(hours=1)).isoformat()})
    assert me.call("patch", "/me/prefs", {"dnd_until": None}).data["dnd_until"] is None


# --- personal email ------------------------------------------------------------------------------------------------

def token_from_mail() -> str:
    return mail.outbox[-1].body.strip().splitlines()[-1]


def test_personal_email_verification_flow_and_important_mail(me, pushes, django_capture_on_commit_callbacks):
    resp = me.call("post", "/me/personal-email", {"email": "Me@Home.test"})
    assert resp.status_code == 200, resp.content
    assert mail.outbox[-1].to == ["me@home.test"]
    prefs = me.call("get", "/me/prefs").data
    assert prefs["personal_email"] == "me@home.test" and prefs["personal_email_verified"] is False
    token = token_from_mail()
    mail.outbox.clear()
    with django_capture_on_commit_callbacks(execute=True):
        notify_module.notify([me.user], "task.assigned", "Before verify")
    assert [m.to for m in mail.outbox] == [[me.user.email]]  # unverified: the account email only
    assert me.call("post", "/me/personal-email/verify", {"token": "x" * 40}).status_code == 400
    ok = me.call("post", "/me/personal-email/verify", {"token": token})
    assert ok.status_code == 200 and ok.data["personal_email_verified"] is True
    mail.outbox.clear()
    with django_capture_on_commit_callbacks(execute=True):
        notify_module.notify([me.user], "task.assigned", "Important")
        notify_module.notify([me.user], "birthday", "Not important")
    assert sorted(m.to[0] for m in mail.outbox) == sorted([me.user.email, me.user.email, "me@home.test"])
    assert [m.subject for m in mail.outbox if m.to == ["me@home.test"]] == ["Important"]


def test_dnd_also_silences_the_personal_email(me, pushes, django_capture_on_commit_callbacks):
    UserPrefs.objects.create(user=me.user, personal_email="me@home.test", personal_email_verified=True,
                             dnd_until=dj_tz.now() + timedelta(hours=1))
    with django_capture_on_commit_callbacks(execute=True):
        notify_module.notify([me.user], "task.assigned", "Quiet")
    assert mail.outbox == [] and pushes == []


def test_token_is_bound_to_the_address_and_the_user(me, make_user, api):
    me.call("post", "/me/personal-email", {"email": "one@home.test"})
    stale = token_from_mail()
    me.call("post", "/me/personal-email", {"email": "two@home.test"})  # a newer address replaces the first
    assert me.call("post", "/me/personal-email/verify", {"token": stale}).status_code == 400
    thief = make_user("thief@corp.test")
    thief_token = api.login(thief.email)["access"]
    good = token_from_mail()
    assert api.call("post", "/me/personal-email/verify", {"token": good}, token=thief_token).status_code == 400
    assert me.call("post", "/me/personal-email/verify", {"token": good}).status_code == 200


def test_personal_email_validation_and_unconfigured_mail(me, settings):
    assert me.call("post", "/me/personal-email", {"email": "not-an-email"}).status_code == 422
    settings.MAILERS = {"default": {"BACKEND": "django.core.mail.backends.smtp.EmailBackend"}}
    assert me.call("post", "/me/personal-email", {"email": "ok@home.test"}).status_code == 503
    assert UserPrefs.objects.filter(personal_email="ok@home.test").count() == 0


def test_personal_email_requests_are_rate_limited(me):
    codes = [me.call("post", "/me/personal-email", {"email": f"a{i}@home.test"}).status_code for i in range(7)]
    assert codes[:5] == [200] * 5 and codes[5:] == [429, 429]


# --- background image ------------------------------------------------------------------------------------------------

def upload(me, data=PNG, name="bg.png"):
    resp = me.client.post("/api/me/background", {"file": SimpleUploadedFile(name, data)},
                          HTTP_AUTHORIZATION=f"Bearer {me.token}")
    resp.data = resp.json() if resp.content else None
    return resp


@pytest.mark.parametrize(("data", "kind"), [(PNG, "image/png"), (JPEG, "image/jpeg"), (WEBP, "image/webp")])
def test_background_roundtrip_is_encrypted(me, data, kind):
    assert upload(me, data).status_code == 200
    resp = me.client.get("/api/me/background", HTTP_AUTHORIZATION=f"Bearer {me.token}")
    assert resp.status_code == 200 and resp["Content-Type"] == kind and resp.content == data
    prefs = UserPrefs.objects.get(user=me.user)
    with prefs.background.open("rb") as handle:
        assert data not in handle.read()  # ciphertext on disk
    assert me.call("get", "/me/prefs").data["has_background"] is True


def test_background_validation(me):
    assert upload(me, b"GIF89a" + b"0" * 20, "bg.gif").status_code == 422
    assert upload(me, b"").status_code == 422
    assert upload(me, PNG + b"0" * (2 * 1024 * 1024)).status_code == 413
    assert upload(me, b"<svg onload=alert(1)>", "bg.png").status_code == 422  # the name is not trusted
    assert me.client.get("/api/me/background", HTTP_AUTHORIZATION=f"Bearer {me.token}").status_code == 404


def test_background_delete_deactivates(me):
    upload(me)
    assert me.call("delete", "/me/background").status_code == 204
    assert me.client.get("/api/me/background", HTTP_AUTHORIZATION=f"Bearer {me.token}").status_code == 404
    assert me.call("delete", "/me/background").status_code == 404
    assert me.call("get", "/me/prefs").data["has_background"] is False
    assert UserPrefs.objects.get(user=me.user).background  # the file is kept, only deactivated
    assert upload(me, JPEG).status_code == 200


def test_background_is_private_to_the_owner(me, make_user, api):
    upload(me)
    other = api.login(make_user("o@corp.test").email)["access"]
    assert api.call("get", "/me/background", token=other).status_code == 404


# --- birthdays and the daily run -------------------------------------------------------------------------------------

def birthday_of(jy, jm, jd) -> date:
    return jalali.to_gregorian(jy, jm, jd)


@pytest.fixture
def colleagues(make_user):
    return make_user("bday@corp.test"), make_user("a@corp.test"), make_user("b@corp.test")


def test_birthdays_notify_colleagues_once_per_day(colleagues, django_capture_on_commit_callbacks):
    star, a, b = colleagues
    star.full_name = "Star Person"
    star.save()
    UserPrefs.objects.create(user=star, birthday=birthday_of(1370, 5, 10))
    today = birthday_of(1405, 5, 10)
    with django_capture_on_commit_callbacks(execute=True):
        assert daily.run_pending(today) == {"birthdays": 1}
    notes = Notification.objects.filter(kind="birthday")
    assert sorted(n.user_id for n in notes) == sorted([a.id, b.id])  # not the birthday person
    assert all(n.title == "Star Person" and n.data == {"user_id": star.id} for n in notes)
    assert daily.run_pending(today) == {}  # idempotent for the day
    assert Notification.objects.filter(kind="birthday").count() == 2
    assert DailyRun.objects.filter(name="birthdays", date=today).count() == 1
    other_day = today + timedelta(days=1)
    assert daily.run_pending(other_day) == {"birthdays": 0}


def test_hidden_missing_and_inactive_birthdays_are_silent(colleagues):
    star, a, b = colleagues
    UserPrefs.objects.create(user=star, birthday=birthday_of(1370, 5, 10), birthday_visible=False)
    UserPrefs.objects.create(user=a, birthday=None)
    UserPrefs.objects.create(user=b, birthday=birthday_of(1380, 5, 10))
    b.is_active = False
    b.save()
    assert daily.run_pending(birthday_of(1405, 5, 10)) == {"birthdays": 0}
    assert Notification.objects.filter(kind="birthday").count() == 0


def test_esfand_30_birthday_is_celebrated_on_29_in_common_years(colleagues):
    star, a, _ = colleagues
    leap_year = next(y for y in range(1400, 1420) if jalali.is_leap(y))
    UserPrefs.objects.create(user=star, birthday=birthday_of(leap_year, 12, 30))
    common = next(y for y in range(1400, 1420) if not jalali.is_leap(y))
    assert daily.run_pending(birthday_of(common, 12, 29)) == {"birthdays": 1}
    assert Notification.objects.filter(kind="birthday", user=a).count() == 1


def test_a_failing_job_does_not_burn_the_days_slot(colleagues, monkeypatch):
    star, _, _ = colleagues
    UserPrefs.objects.create(user=star, birthday=birthday_of(1370, 5, 10))
    today = birthday_of(1405, 5, 10)

    def boom(*args, **kwargs):
        raise RuntimeError("down")

    monkeypatch.setattr(daily, "notify", boom)
    with pytest.raises(RuntimeError):
        daily.run_pending(today)
    assert DailyRun.objects.count() == 0  # rolled back together with the work
    monkeypatch.undo()
    assert daily.run_pending(today) == {"birthdays": 1}


def test_run_daily_command_and_run_reminders_tick(colleagues, capsys):
    star, _, _ = colleagues
    today = daily.tehran_today()
    jy, jm, jd = jalali.to_jalali(today)
    UserPrefs.objects.create(user=star, birthday=jalali.to_gregorian(jy - 20, jm, min(jd, 28)))
    call_command("run_daily")
    first = capsys.readouterr().out
    assert "birthdays" in first
    call_command("run_daily")
    assert "nothing to do" in capsys.readouterr().out
    call_command("run_reminders", "--once")  # the reminder loop calls the same guarded job
    assert DailyRun.objects.filter(name="birthdays", date=today).count() == 1


def test_daily_guard_rows_cannot_be_deleted(db):
    from django.db import IntegrityError, connection

    DailyRun.objects.create(name="x", date=date(2030, 1, 1))
    with pytest.raises(Exception) as err, connection.cursor() as cursor:
        cursor.execute("DELETE FROM accounts_dailyrun")
    assert "not allowed" in str(err.value) or isinstance(err.value, IntegrityError)

