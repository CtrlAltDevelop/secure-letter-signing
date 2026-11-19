"""Reminders: create/list/deactivate for the caller, and `fire_due_reminders` (run every tick by the scheduler)."""
import logging
from datetime import datetime

from django.db import transaction
from django.utils import timezone
from ninja.errors import HttpError

from accounts.models import User
from accounts.notify import notify

from . import recurrence, registry
from .models import Reminder, Subject

logger = logging.getLogger(__name__)
MAX_ACTIVE_PER_SUBJECT = 50
KIND = "reminder"


def mine(user: User, subject: Subject) -> list[Reminder]:
    return list(Reminder.objects.filter(subject=subject, user=user, active=True).order_by("next_at", "id"))


@transaction.atomic
def create(user: User, subject: Subject, at: datetime, rule: dict | None) -> Reminder:
    if at.tzinfo is None:
        raise HttpError(422, "at must include a time zone offset")
    if at <= timezone.now():
        raise HttpError(422, "at must be in the future")
    try:
        clean = recurrence.clean_rule(rule, at) if rule else None
    except recurrence.RuleError as exc:
        raise HttpError(422, str(exc)) from exc
    Subject.objects.select_for_update().get(pk=subject.pk)  # serialises the per-subject cap
    if Reminder.objects.filter(subject=subject, user=user, active=True).count() >= MAX_ACTIVE_PER_SUBJECT:
        raise HttpError(422, f"At most {MAX_ACTIVE_PER_SUBJECT} reminders per item")
    return Reminder.objects.create(subject=subject, user=user, created_by=user, next_at=at, rule=clean)


def deactivate(user: User, reminder_id: int) -> None:
    updated = Reminder.objects.filter(pk=reminder_id, user=user, active=True).update(active=False)
    if not updated:
        raise HttpError(404, "Not found")


def _can_still_see(user: User, subject: Subject):
    """(object, spec) when the module is on and the user can still see the object, else None."""
    if subject.module not in registry.enabled_modules():
        return None
    spec = registry.get(subject.module)
    obj = spec.resolve(subject) if spec else None
    if obj is None or not spec.can(user, obj, "see"):
        return None
    return obj, spec


def _advance(row: Reminder, now: datetime) -> None:
    row.last_fired_at = now
    if not row.rule:
        row.active = False
        return
    row.next_at = recurrence.next_occurrence(row.rule, row.next_at, now)


def _fire(row: Reminder, now: datetime) -> bool:
    """Notify for one due row and move it on. False when it was dropped or skipped without a notification."""
    if not row.user.is_active:
        return False
    found = _can_still_see(row.user, row.subject)
    if found is None:  # gone, switched off, or the user lost access: stop reminding, say nothing
        row.active = False
        row.save(update_fields=["active"])
        return False
    obj, spec = found
    title = spec.title(obj) if spec.title else ""
    notify([row.user], KIND, title, module=row.subject.module, subject_id=str(row.subject_id),
           object_id=str(getattr(obj, "pk", "")))
    _advance(row, now)
    row.save(update_fields=["next_at", "active", "last_fired_at"])
    return True


@transaction.atomic
def fire_due_reminders(now: datetime | None = None) -> int:
    """Notify every active reminder due at `now`; recurring ones move to their next occurrence after `now` (missed
    ones are not replayed), one-shot ones are deactivated. Safe to run concurrently and repeatedly. Returns the count."""
    now = now or timezone.now()
    due = (Reminder.objects.select_for_update(skip_locked=True, of=("self",))
           .filter(active=True, next_at__lte=now).select_related("user", "subject").order_by("next_at", "id"))
    return sum(1 for row in due if _fire(row, now))
