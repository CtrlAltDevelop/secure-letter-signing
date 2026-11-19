"""Once-a-day jobs, idempotent per Tehran-local date through a `DailyRun` guard row.

`run_pending()` is cheap enough to call on every `run_reminders` tick: after the first run of the day it only costs one
indexed lookup per job.
"""
import logging
from collections.abc import Callable
from datetime import date

from django.db import IntegrityError, transaction
from django.utils import timezone

from workspace import jalali
from workspace.recurrence import TEHRAN

from .models import DailyRun, User, UserPrefs
from .notify import notify

logger = logging.getLogger(__name__)
BIRTHDAY_KIND = "birthday"


def tehran_today() -> date:
    return timezone.now().astimezone(TEHRAN).date()


def _jalali_birthday_today(birthday: date, today: date) -> bool:
    """Same Jalali month and day (a 30 Esfand birthday is celebrated on 29 Esfand in common years)."""
    _, bm, bd = jalali.to_jalali(birthday)
    jy, tm, td = jalali.to_jalali(today)
    if (bm, bd) == (12, 30) and not jalali.is_leap(jy):
        bd = 29
    return (bm, bd) == (tm, td)


def notify_birthdays(today: date) -> int:
    """Tell every colleague about each visible birthday today; returns how many birthdays were announced."""
    rows = UserPrefs.objects.filter(birthday__isnull=False, birthday_visible=True, user__is_active=True)
    people = [p.user for p in rows.select_related("user") if _jalali_birthday_today(p.birthday, today)]
    for person in people:
        others = list(User.objects.filter(is_active=True).exclude(pk=person.pk))
        notify(others, BIRTHDAY_KIND, person.full_name or person.email, user_id=person.id)
    return len(people)


JOBS: tuple[tuple[str, Callable[[date], int]], ...] = (("birthdays", notify_birthdays),)


def _run_once(name: str, job: Callable[[date], int], today: date) -> int | None:
    """Claim (name, today) and run the job in one transaction; None when it already ran today."""
    if DailyRun.objects.filter(name=name, date=today).exists():
        return None
    try:
        with transaction.atomic():
            DailyRun.objects.create(name=name, date=today)  # the unique constraint is the lock
            return job(today)
    except IntegrityError:
        return None  # a concurrent runner won


def run_pending(today: date | None = None) -> dict[str, int]:
    today = today or tehran_today()
    done: dict[str, int] = {}
    for name, job in JOBS:
        count = _run_once(name, job, today)
        if count is not None:
            done[name] = count
    return done
