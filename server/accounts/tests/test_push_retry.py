import warnings

import pytest
from django.utils import timezone

from accounts import mailer, push
from accounts.models import CompanySettings, DeviceToken, UserPrefs
from accounts.notify import notify


class FakeSender:
    def __init__(self, dead=()):
        self.calls, self.dead = [], list(dead)

    def send(self, tokens, title):
        self.calls.append((tokens, title))
        return self.dead


@pytest.fixture
def fake(monkeypatch):
    sender = FakeSender()
    monkeypatch.setattr(push, "get_sender", lambda: sender)
    return sender


def test_register_and_delete_token(make_user, api):
    user = make_user("p@corp.test")
    tok = api.login(user.email)["access"]
    assert api.call("post", "/me/push-token", {"token": "t1", "platform": "android"}, token=tok).status_code == 204
    assert api.call("post", "/me/push-token", {"token": "t1", "platform": "ios"}, token=tok).status_code == 204
    assert list(DeviceToken.objects.values_list("platform", flat=True)) == ["ios"]
    assert api.call("delete", "/me/push-token", None, token=tok).status_code == 204
    assert DeviceToken.objects.count() == 0


def test_notify_pushes_title_only_and_honours_dnd(make_user, fake, django_capture_on_commit_callbacks):
    user, quiet = make_user("a@corp.test"), make_user("b@corp.test")
    for u in (user, quiet):
        DeviceToken.objects.create(user=u, token=f"tok-{u.id}", platform="android")
    UserPrefs.objects.create(user=quiet, dnd_until=timezone.now() + timezone.timedelta(hours=1))
    with django_capture_on_commit_callbacks(execute=True):
        notify([user, quiet], "mention", "Hello", secret="x")
    assert fake.calls == [([f"tok-{user.id}"], "Hello")]


def test_guest_gets_no_push_and_dead_tokens_deleted(make_user, fake):
    guest = make_user("g@corp.test")
    guest.is_guest = True
    DeviceToken.objects.create(user=guest, token="g1", platform="ios")
    push.push_title(guest, "x")
    assert fake.calls == []
    user = make_user("u@corp.test")
    DeviceToken.objects.create(user=user, token="dead", platform="ios")
    fake.dead = ["dead"]
    push.push_title(user, "x")
    assert DeviceToken.objects.filter(user=user).count() == 0


def test_mail_retries_then_succeeds(db, monkeypatch):
    CompanySettings.objects.update_or_create(pk=1, defaults={"smtp_host": "smtp.test"})
    monkeypatch.setattr(mailer, "RETRY_DELAYS", (0, 0, 0))
    results = iter([False, False, True])
    monkeypatch.setattr(mailer, "send", lambda *a: next(results))
    mailer._deliver("a@b.test", "s", "b")
    assert next(results, "drained") == "drained"


def test_mail_final_failure_logged(db, monkeypatch, caplog):
    CompanySettings.objects.update_or_create(pk=1, defaults={"smtp_host": "smtp.test"})
    monkeypatch.setattr(mailer, "RETRY_DELAYS", (0, 0, 0))
    calls = []
    monkeypatch.setattr(mailer, "send", lambda *a: calls.append(1) or False)
    mailer._deliver("a@b.test", "s", "b")
    assert len(calls) == 4 and "failed after 4 attempts" in caplog.text


def test_smtp_connection_no_deprecation(db, monkeypatch, settings):
    settings.MAILERS = {"default": {"BACKEND": mailer.SMTP_BACKEND}}
    CompanySettings.objects.update_or_create(pk=1, defaults={"smtp_host": "127.0.0.1", "smtp_port": 1})
    with warnings.catch_warnings():
        warnings.simplefilter("error", DeprecationWarning)
        assert mailer.send("a@b.test", "s", "b") is False  # connection refused -> OSError handled
