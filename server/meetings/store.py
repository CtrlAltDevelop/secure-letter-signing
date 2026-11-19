"""Row access for meetings: locking and permission checks shared by the services."""
from uuid import UUID

from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja.errors import HttpError

from accounts.models import User

from . import rules
from .models import Meeting


def lock_meeting(user: User, meeting_id: UUID) -> Meeting:
    """The meeting row locked for update; 404 unless the user can see it. Call inside `transaction.atomic`."""
    meeting = get_object_or_404(Meeting.objects.select_for_update().select_related("subject", "creator"),
                                pk=meeting_id)
    if not rules.can(user, meeting, "see"):
        raise HttpError(404, "Not found")
    return meeting


def require(user: User, meeting: Meeting, action: str) -> None:
    if not rules.can(user, meeting, action):
        raise HttpError(403, "Permission denied")


def require_status(meeting: Meeting, *allowed: str) -> None:
    if meeting.status not in allowed:
        raise HttpError(409, f"The meeting is {meeting.status}")


def save(meeting: Meeting) -> None:
    meeting.updated_at = timezone.now()
    meeting.save()


def visible_meeting(user: User, meeting_id: UUID) -> Meeting:
    """The meeting (not locked); 404 unless the user can see it."""
    meeting = get_object_or_404(Meeting.objects.select_related("subject", "creator"), pk=meeting_id)
    if not rules.can(user, meeting, "see"):
        raise HttpError(404, "Not found")
    return meeting
