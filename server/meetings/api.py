"""Meetings API (mounted at /api/meetings). Rules in rules.py, state changes in service/lifecycle/attendees/resolutions."""
from datetime import datetime
from uuid import UUID

from django.db.models import Q
from ninja import Query, Router

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, user_of
from accounts.models import User
from workspace import registry
from workspace.seen import mark_seen

from . import attendees, lifecycle, resolutions, rules, service, signing, store
from .models import Meeting, MeetingAttendee
from .schemas import (AttendanceIn, AttendeeIn, MeetingBrief, MeetingIn, MeetingOut, MeetingPatch, RemindIn,
                      RemindOut, ResolutionIn, ResolutionOut, ResolutionPatch, SignBiometricIn, SignPinIn, SmsIn,
                      SmsOut)
from .serializers import briefs, meeting_out, resolution_out

router = Router(tags=["meetings"], auth=BearerAuth())
ERRORS = {403: Detail, 404: Detail, 409: Detail, 422: Detail}
MAX_LIMIT = 200


def _gate() -> None:
    registry.require_module("meetings")


def _out(user: User, meeting: Meeting) -> MeetingOut:
    return meeting_out(user, Meeting.objects.select_related("subject", "creator").get(pk=meeting.pk))


def _filtered(user: User, status: str, kind: str, q: str, from_: datetime | None, to: datetime | None,
              project: UUID | None, mine: bool, customer: UUID | None = None):
    rows = rules.visible_meetings(user)
    if status:
        rows = rows.filter(status=status)
    if kind:
        rows = rows.filter(kind=kind)
    if q:
        rows = rows.filter(title__icontains=q)
    if from_:
        rows = rows.filter(starts_at__gte=from_)
    if to:
        rows = rows.filter(starts_at__lte=to)
    if project:
        rows = rows.filter(project_id=project)
    if customer:
        rows = rows.filter(customer_id=customer)
    if mine:
        own = MeetingAttendee.objects.filter(user=user, active=True).exclude(role="guest").values("meeting_id")
        rows = rows.filter(Q(creator=user) | Q(pk__in=own))
    return rows


@router.post("", response={201: MeetingOut, **ERRORS})
def create(request, data: MeetingIn):
    _gate()
    user = user_of(request)
    return 201, _out(user, service.create_meeting(user, data))


@router.get("", response=list[MeetingBrief])
def list_meetings(request, status: str = "", kind: str = "", q: str = "", from_: datetime | None = Query(None, alias="from"),
                  to: datetime | None = None, project: UUID | None = None, mine: bool = False,
                  customer: UUID | None = None, limit: int = 50, offset: int = 0):
    _gate()
    user = user_of(request)
    start = max(offset, 0)
    rows = _filtered(user, status, kind, q, from_, to, project, mine, customer).select_related("subject").order_by(
        "-starts_at", "-created_at")
    return briefs(user, list(rows[start : start + max(min(limit, MAX_LIMIT), 0)]))


@router.get("/{uuid:meeting_id}", response={200: MeetingOut, 404: Detail})
def get_meeting(request, meeting_id: UUID):
    _gate()
    user = user_of(request)
    meeting = store.visible_meeting(user, meeting_id)
    mark_seen(user, meeting.subject)
    return _out(user, meeting)


@router.patch("/{uuid:meeting_id}", response={200: MeetingOut, **ERRORS})
def patch_meeting(request, meeting_id: UUID, data: MeetingPatch):
    _gate()
    user = user_of(request)
    return _out(user, service.update_meeting(user, meeting_id, data))


@router.put("/{uuid:meeting_id}/attendees", response={200: MeetingOut, **ERRORS})
def put_attendees(request, meeting_id: UUID, data: list[AttendeeIn]):
    _gate()
    user = user_of(request)
    return _out(user, attendees.set_attendees(user, meeting_id, data))


@router.post("/{uuid:meeting_id}/attendance", response={200: MeetingOut, **ERRORS})
def post_attendance(request, meeting_id: UUID, data: AttendanceIn):
    _gate()
    user = user_of(request)
    return _out(user, attendees.mark_attendance(user, meeting_id, data))


@router.post("/{uuid:meeting_id}/resolutions", response={201: ResolutionOut, **ERRORS})
def add_resolution(request, meeting_id: UUID, data: ResolutionIn):
    _gate()
    user = user_of(request)
    row = resolutions.add(user, meeting_id, data)
    return 201, _resolution(row)


@router.patch("/{uuid:meeting_id}/resolutions/{int:resolution_id}", response={200: ResolutionOut, **ERRORS})
def patch_resolution(request, meeting_id: UUID, resolution_id: int, data: ResolutionPatch):
    _gate()
    user = user_of(request)
    return _resolution(resolutions.edit(user, meeting_id, resolution_id, data))


def _resolution(row) -> ResolutionOut:
    from tasks.models import Task

    row.refresh_from_db()
    return resolution_out(row, Task.objects.in_bulk([row.task_id]) if row.task_id else {})


def _transition(fn):
    def view(request, meeting_id: UUID):
        _gate()
        user = user_of(request)
        return _out(user, fn(user, meeting_id))

    view.__name__ = fn.__name__
    return view


for _name, _fn in (("schedule", lifecycle.schedule), ("hold", lifecycle.hold), ("close", lifecycle.close),
                   ("reopen", lifecycle.reopen), ("cancel", lifecycle.cancel)):
    router.post(f"/{{uuid:meeting_id}}/{_name}", response={200: MeetingOut, **ERRORS})(_transition(_fn))


@router.post("/{uuid:meeting_id}/sign", response={200: MeetingOut, **ERRORS})
def sign(request, meeting_id: UUID, data: SignPinIn):
    _gate()
    user = user_of(request)
    return _out(user, signing.sign_with_pin(user, request.auth, meeting_id, data, data.pin))


@router.post("/{uuid:meeting_id}/sign-biometric", response={200: MeetingOut, **ERRORS})
def sign_biometric(request, meeting_id: UUID, data: SignBiometricIn):
    _gate()
    user = user_of(request)
    return _out(user, signing.sign_with_biometric(user, request.auth, meeting_id, data))


@router.post("/{uuid:meeting_id}/remind", response={200: RemindOut, **ERRORS})
def remind(request, meeting_id: UUID, data: RemindIn):
    _gate()
    return RemindOut(reminders=lifecycle.remind(user_of(request), meeting_id, data.offset_minutes))


@router.post("/{uuid:meeting_id}/sms", response={200: SmsOut, **ERRORS})
def send_sms(request, meeting_id: UUID, data: SmsIn):
    _gate()
    sent, without = lifecycle.send_sms(user_of(request), meeting_id, data.text)
    return SmsOut(sent=sent, without_phone=without)

