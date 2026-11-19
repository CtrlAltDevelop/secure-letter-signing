"""Meeting state changes (schedule, hold, close, reopen, cancel), reminders and SMS to attendees."""
from datetime import timedelta
from uuid import UUID

from django.db import transaction
from django.utils import timezone
from ninja.errors import HttpError

from accounts.models import User, audit
from core import sms
from workspace.models import Reminder
from workspace.seen import mark_seen

from . import content, history, notices, rules, store
from .models import Meeting, MeetingAttendee


def _set_status(meeting: Meeting, user: User, status: str) -> None:
    history.log(meeting.subject, user, "status", meeting.status, status)
    meeting.status = status
    store.save(meeting)


def _user_attendee_ids(meeting: Meeting) -> list[int]:
    return list(MeetingAttendee.objects.filter(meeting=meeting, active=True, user__isnull=False, user__is_active=True)
                .values_list("user_id", flat=True))


def _finish(meeting: Meeting, user: User, kind: str, notice: str | None = None) -> Meeting:
    audit(user, f"meeting_{kind}", str(meeting.id), revision=meeting.revision)
    notices.emit_meeting(f"meeting.{kind}", meeting, user)
    if notice:
        notices.notify_users(_user_attendee_ids(meeting), notice, meeting, user)
    mark_seen(user, meeting.subject)
    return meeting


@transaction.atomic
def schedule(user: User, meeting_id: UUID) -> Meeting:
    meeting = store.lock_meeting(user, meeting_id)
    store.require(user, meeting, "manage")
    store.require_status(meeting, Meeting.DRAFT)
    if meeting.starts_at is None:
        raise HttpError(422, "A scheduled meeting needs a start time")
    _set_status(meeting, user, Meeting.SCHEDULED)
    return _finish(meeting, user, "scheduled", "meeting.invited")


@transaction.atomic
def hold(user: User, meeting_id: UUID) -> Meeting:
    meeting = store.lock_meeting(user, meeting_id)
    store.require(user, meeting, "chair")
    store.require_status(meeting, Meeting.SCHEDULED)
    _set_status(meeting, user, Meeting.HELD)
    return _finish(meeting, user, "held", "meeting.held")


@transaction.atomic
def close(user: User, meeting_id: UUID) -> Meeting:
    meeting = store.lock_meeting(user, meeting_id)
    store.require(user, meeting, "chair")
    store.require_status(meeting, Meeting.HELD)
    _set_status(meeting, user, Meeting.CLOSED)
    return _finish(meeting, user, "closed", "meeting.closed")


@transaction.atomic
def reopen(user: User, meeting_id: UUID) -> Meeting:
    """Back to `held` with a new revision: earlier signatures stay stored but are reported stale."""
    meeting = store.lock_meeting(user, meeting_id)
    store.require(user, meeting, "chair")
    store.require_status(meeting, Meeting.HELD, Meeting.CLOSED)
    if meeting.status == Meeting.HELD and not content.current_signatures(meeting).exists():
        raise HttpError(409, "Nothing to reopen: the minutes are not signed")
    history.log(meeting.subject, user, "revision", meeting.revision, meeting.revision + 1)
    meeting.revision += 1
    _set_status(meeting, user, Meeting.HELD)
    return _finish(meeting, user, "reopened", "meeting.reopened")


@transaction.atomic
def cancel(user: User, meeting_id: UUID) -> Meeting:
    meeting = store.lock_meeting(user, meeting_id)
    store.require(user, meeting, "manage")
    store.require_status(meeting, Meeting.DRAFT, Meeting.SCHEDULED)
    _set_status(meeting, user, Meeting.CANCELLED)
    return _finish(meeting, user, "cancelled", "meeting.cancelled")


@transaction.atomic
def remind(user: User, meeting_id: UUID, offset_minutes: int) -> int:
    """A notification reminder for each attendee at `starts_at - offset`. Returns how many were created."""
    meeting = store.lock_meeting(user, meeting_id)
    store.require(user, meeting, "record")
    store.require_status(meeting, Meeting.SCHEDULED)
    if meeting.starts_at is None:
        raise HttpError(422, "The meeting has no start time")
    at = meeting.starts_at - timedelta(minutes=offset_minutes)
    if at <= timezone.now():
        raise HttpError(422, "The reminder time is in the past")
    created = 0
    for uid in _user_attendee_ids(meeting):
        _, new = Reminder.objects.get_or_create(subject=meeting.subject, user_id=uid, next_at=at, active=True,
                                                defaults={"created_by": user})
        created += new
    history.log(meeting.subject, user, "reminder", None, {"offset_minutes": offset_minutes, "count": created})
    return created


def send_sms(user: User, meeting_id: UUID, text: str) -> tuple[int, int]:
    """(sent, without_phone). Chair/secretary only; the audit row has ids and counts, never the text."""
    with transaction.atomic():
        meeting = store.lock_meeting(user, meeting_id)
        if not rules.can_run(meeting, user):
            raise HttpError(403, "Permission denied")
        store.require_status(meeting, Meeting.SCHEDULED, Meeting.HELD)
        phones = list(User.objects.filter(pk__in=_user_attendee_ids(meeting)).exclude(phone__isnull=True)
                      .exclude(phone="").values_list("phone", flat=True))
        total = len(_user_attendee_ids(meeting))
        if not phones:
            raise HttpError(422, "No attendee has a phone number")
        sms.send_sms(phones, text)
        audit(user, "meeting_sms", str(meeting.id), recipients=len(phones))
    return len(phones), total - len(phones)
