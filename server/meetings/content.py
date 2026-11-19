"""The minutes as they are signed: description + active resolutions + attendance. Plaintext canonical JSON is hashed."""
from ninja.errors import HttpError

from core import cryptoutil
from workspace.textbox import open_text

from .models import Meeting, MeetingAttendee, MeetingMinutesSignature, Resolution, ResolutionOwner


def _attendee_row(a: MeetingAttendee) -> dict:
    return {"userId": a.user_id, "guest": a.guest_name, "role": a.role, "attendance": a.attendance}


def _resolution_row(r: Resolution, owners: list[int]) -> dict:
    return {"id": r.id, "text": open_text(r.text), "dueAt": r.due_at.isoformat() if r.due_at else None,
            "owners": owners}


def minutes_content(meeting: Meeting) -> dict:
    """Resolution status is left out on purpose: it mirrors the follow-up task and changes after signing."""
    attendees = MeetingAttendee.objects.filter(meeting=meeting, active=True).order_by("id")
    resolutions = Resolution.objects.filter(meeting=meeting, active=True).order_by("id")
    owners: dict[int, list[int]] = {}
    for o in ResolutionOwner.objects.filter(resolution__in=resolutions, active=True).order_by("user_id"):
        owners.setdefault(o.resolution_id, []).append(o.user_id)
    return {
        "description": open_text(meeting.description),
        "resolutions": [_resolution_row(r, owners.get(r.id, [])) for r in resolutions],
        "attendance": sorted((_attendee_row(a) for a in attendees),
                             key=lambda row: (row["userId"] or 0, row["guest"])),
    }


def content_hash(meeting: Meeting) -> str:
    return cryptoutil.content_hash(minutes_content(meeting))


def current_signatures(meeting: Meeting):
    return MeetingMinutesSignature.objects.filter(meeting=meeting, revision=meeting.revision)


def require_minutes_editable(meeting: Meeting) -> None:
    """Minutes (description, resolutions, attendance) are frozen when closed/cancelled or once anyone signed this
    revision; the chair must reopen first (which starts a new revision)."""
    if meeting.status in (Meeting.CLOSED, Meeting.CANCELLED):
        raise HttpError(409, f"The meeting is {meeting.status}")
    if current_signatures(meeting).exists():
        raise HttpError(409, "The minutes are signed; the chair must reopen the meeting to change them")
