"""Who may do what with a meeting. Visible to the creator and active attendees only (the manager gets nothing).

Leaders: the chair, the secretary, and the creator of a simple meeting (who acts as chair when nobody holds the role).
"""
from accounts.models import User

from .models import Meeting, MeetingAttendee

CHAIR, SECRETARY = MeetingAttendee.CHAIR, MeetingAttendee.SECRETARY
SEE_ACTIONS = {"see", "comment", "label"}


def attendee_roles(meeting: Meeting, user: User) -> set[str]:
    return set(MeetingAttendee.objects.filter(meeting=meeting, user=user, active=True).values_list("role", flat=True))


def is_creator(meeting: Meeting, user: User) -> bool:
    return meeting.creator_id == user.id


def is_chair(meeting: Meeting, user: User) -> bool:
    if CHAIR in attendee_roles(meeting, user):
        return True
    return meeting.kind == Meeting.SIMPLE and is_creator(meeting, user)


def is_secretary(meeting: Meeting, user: User) -> bool:
    return SECRETARY in attendee_roles(meeting, user)


def can_manage(meeting: Meeting, user: User) -> bool:
    """Fields, attendees, scheduling, cancelling."""
    return is_creator(meeting, user) or is_chair(meeting, user)


def can_record(meeting: Meeting, user: User) -> bool:
    """Minutes (description, resolutions)."""
    return can_manage(meeting, user) or is_secretary(meeting, user)


def can_run(meeting: Meeting, user: User) -> bool:
    """Attendance, SMS to attendees: chair or secretary."""
    return is_chair(meeting, user) or is_secretary(meeting, user)


def can(user: User, meeting: Meeting, action: str) -> bool:
    if not (is_creator(meeting, user) or attendee_roles(meeting, user)):
        return False
    if action in SEE_ACTIONS:
        return True
    if action == "moderate":
        return can_manage(meeting, user)
    return {"manage": can_manage, "record": can_record, "run": can_run, "chair": is_chair}.get(
        action, lambda m, u: False)(meeting, user)


def audience(meeting: Meeting) -> set[int]:
    ids = set(MeetingAttendee.objects.filter(meeting=meeting, active=True, user__isnull=False, user__is_active=True)
              .values_list("user_id", flat=True))
    ids.add(meeting.creator_id)
    return ids


def visible_meetings(user: User):
    from django.db.models import Q

    attending = MeetingAttendee.objects.filter(user=user, active=True).values("meeting_id")
    return Meeting.objects.filter(Q(creator=user) | Q(pk__in=attending))
