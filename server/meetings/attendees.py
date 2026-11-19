"""Attendee lists (chair/secretary rules, guests) and attendance marks."""
from django.db import transaction
from ninja.errors import HttpError

from accounts.models import User
from workspace.seen import mark_seen

from . import content, history, notices, store
from .models import Meeting, MeetingAttendee
from .schemas import AttendanceIn, AttendeeIn

CHAIR, SECRETARY, GUEST = MeetingAttendee.CHAIR, MeetingAttendee.SECRETARY, MeetingAttendee.GUEST


def _check_each(entries: list[AttendeeIn]) -> None:
    seen_users, seen_guests = set(), set()
    for e in entries:
        name = e.guest_name.strip()
        if bool(e.user_id) == bool(name):
            raise HttpError(422, "Each attendee needs either a user or a guest name")
        if e.user_id is None and e.role != GUEST:
            raise HttpError(422, "An external guest must have the guest role")
        key, bucket = (e.user_id, seen_users) if e.user_id else (name, seen_guests)
        if key in bucket:
            raise HttpError(422, "Duplicate attendee")
        bucket.add(key)
    users = {e.user_id for e in entries if e.user_id}
    if User.objects.filter(pk__in=users, is_active=True).count() != len(users):
        raise HttpError(422, "Unknown or inactive user")


def validate(kind: str, entries: list[AttendeeIn]) -> None:
    """422 unless the list is acceptable: organizational meetings need exactly one chair and one secretary."""
    _check_each(entries)
    for role in (CHAIR, SECRETARY):
        count = sum(1 for e in entries if e.role == role)
        if count > 1 or (kind == Meeting.ORGANIZATIONAL and count != 1):
            raise HttpError(422, f"An organizational meeting needs exactly one {role}"
                            if kind == Meeting.ORGANIZATIONAL else f"At most one {role}")


def current_entries(meeting: Meeting) -> list[AttendeeIn]:
    rows = MeetingAttendee.objects.filter(meeting=meeting, active=True).order_by("id")
    return [AttendeeIn(user_id=a.user_id, guest_name=a.guest_name, role=a.role) for a in rows]


def _key(user_id: int | None, guest: str) -> tuple:
    return ("u", user_id) if user_id else ("g", guest.strip())


def _snapshot(entries: list[AttendeeIn]) -> list[dict]:
    return sorted(({"user_id": e.user_id, "guest": e.guest_name.strip(), "role": e.role} for e in entries),
                  key=lambda r: (r["user_id"] or 0, r["guest"]))


def apply(meeting: Meeting, actor: User, entries: list[AttendeeIn]) -> list[int]:
    """Make `entries` the active attendees (others are deactivated, attendance is kept). Returns newly added user ids."""
    existing = {_key(a.user_id, a.guest_name): a for a in MeetingAttendee.objects.filter(meeting=meeting)}
    wanted, added = set(), []
    for e in entries:
        key = _key(e.user_id, e.guest_name)
        wanted.add(key)
        row = existing.get(key)
        if row is None:
            MeetingAttendee.objects.create(meeting=meeting, user_id=e.user_id, guest_name=e.guest_name.strip(),
                                           role=e.role, added_by=actor)
            if e.user_id:
                added.append(e.user_id)
        elif not row.active or row.role != e.role:
            if not row.active and row.user_id:
                added.append(row.user_id)
            row.active, row.role = True, e.role
            row.save(update_fields=["active", "role"])
    for key, row in existing.items():
        if key not in wanted and row.active:
            row.active = False
            row.save(update_fields=["active"])
    return added


@transaction.atomic
def set_attendees(user: User, meeting_id, entries: list[AttendeeIn]) -> Meeting:
    meeting = store.lock_meeting(user, meeting_id)
    store.require(user, meeting, "manage")
    store.require_status(meeting, Meeting.DRAFT, Meeting.SCHEDULED)
    validate(meeting.kind, entries)
    old = _snapshot(current_entries(meeting))
    added = apply(meeting, user, entries)
    history.log(meeting.subject, user, "attendees", old, _snapshot(entries))
    if meeting.status == Meeting.SCHEDULED:
        notices.notify_users(added, "meeting.invited", meeting, user)
    store.save(meeting)
    notices.emit_meeting("meeting.updated", meeting, user, fields=["attendees"])
    mark_seen(user, meeting.subject)
    return meeting


def _find(meeting: Meeting, data: AttendanceIn) -> MeetingAttendee:
    rows = MeetingAttendee.objects.filter(meeting=meeting, active=True)
    if data.attendee_id is not None:
        row = rows.filter(pk=data.attendee_id).first()
    elif data.user_id is not None:
        row = rows.filter(user_id=data.user_id).first()
    else:
        raise HttpError(422, "attendee_id or user_id is required")
    if row is None:
        raise HttpError(404, "Not found")
    return row


@transaction.atomic
def mark_attendance(user: User, meeting_id, data: AttendanceIn) -> Meeting:
    meeting = store.lock_meeting(user, meeting_id)
    store.require(user, meeting, "run")
    store.require_status(meeting, Meeting.SCHEDULED, Meeting.HELD)
    content.require_minutes_editable(meeting)
    row = _find(meeting, data)
    if row.attendance != data.attendance:
        history.log(meeting.subject, user, f"attendance:{row.id}", row.attendance, data.attendance)
        row.attendance = data.attendance
        row.save(update_fields=["attendance"])
        store.save(meeting)
        notices.emit_meeting("meeting.updated", meeting, user, fields=["attendance"])
    mark_seen(user, meeting.subject)
    return meeting
