from datetime import datetime
from typing import Any
from uuid import UUID

from ninja import Field, Schema

from workspace.schemas import UserRef

MAX_ATTENDEES = 200
ROLE = "^(chair|secretary|member|guest)$"
ATTENDANCE = "^(unknown|present|absent|excused)$"
KIND = "^(simple|organizational)$"


class TextIn(Schema):
    text: str = Field("", max_length=50_000)


class AttendeeIn(Schema):
    user_id: int | None = None
    guest_name: str = Field("", max_length=150)  # external guest: no user_id
    role: str = Field("member", pattern=ROLE)


class MeetingIn(Schema):
    title: str | None = Field(None, min_length=1, max_length=200)  # may come from the template's name otherwise
    kind: str | None = Field(None, pattern=KIND)
    location: str | None = Field(None, max_length=200)
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    description: TextIn | None = None
    project_id: UUID | None = None
    customer_id: UUID | None = None
    attendees: list[AttendeeIn] | None = Field(None, max_length=MAX_ATTENDEES)
    template_id: int | None = None
    status: str = Field("scheduled", pattern="^(draft|scheduled)$")


class MeetingPatch(Schema):
    title: str | None = Field(None, min_length=1, max_length=200)
    kind: str | None = Field(None, pattern=KIND)
    location: str | None = Field(None, max_length=200)
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    description: TextIn | None = None
    project_id: UUID | None = None
    customer_id: UUID | None = None


class AttendanceIn(Schema):
    user_id: int | None = None
    attendee_id: int | None = None
    attendance: str = Field(pattern=ATTENDANCE)


class ResolutionIn(Schema):
    text: str = Field(min_length=1, max_length=20_000)
    due_at: datetime | None = None
    owner_ids: list[int] = Field(default_factory=list, max_length=50)


class ResolutionPatch(Schema):
    text: str | None = Field(None, min_length=1, max_length=20_000)
    due_at: datetime | None = None
    owner_ids: list[int] | None = Field(None, max_length=50)
    status: str | None = Field(None, pattern="^(open|done|cancelled)$")
    active: bool | None = None  # false deactivates (and cancels the follow-up task)


class SignPinIn(Schema):
    decision: str = Field(pattern="^(approved|rejected)$")
    note: str = Field("", max_length=2000)
    pin: str = Field(min_length=1, max_length=64)


class SignBiometricIn(Schema):
    decision: str = Field(pattern="^(approved|rejected)$")
    note: str = Field("", max_length=2000)


class RemindIn(Schema):
    offset_minutes: int = Field(ge=0, le=60 * 24 * 30)


class SmsIn(Schema):
    text: str = Field(min_length=1, max_length=500)


class TemplateAttendee(Schema):
    user_id: int
    role: str = Field(pattern=ROLE)


class TemplateData(Schema):
    kind: str = Field("simple", pattern=KIND)
    location: str = Field("", max_length=200)
    description: str = Field("", max_length=50_000)
    attendees: list[TemplateAttendee] = Field(default_factory=list, max_length=MAX_ATTENDEES)


class TemplateIn(Schema):
    name: str = Field(min_length=1, max_length=100)
    scope: str = Field("personal", pattern="^(org|personal)$")
    data: TemplateData


class TemplatePatch(Schema):
    name: str | None = Field(None, min_length=1, max_length=100)
    data: TemplateData | None = None
    active: bool | None = None


class TemplateOut(Schema):
    id: int
    name: str
    scope: str
    owner_id: int | None
    data: dict[str, Any]
    active: bool


class AttendeeOut(Schema):
    id: int
    user: UserRef | None
    guest_name: str
    role: str
    attendance: str


class ResolutionOut(Schema):
    id: int
    text: str
    due_at: datetime | None
    status: str
    owner_ids: list[int]
    task_id: UUID | None
    task_status: str | None
    task_progress: int | None
    created_at: datetime


class SignatureOut(Schema):
    id: int
    user: UserRef
    decision: str
    note: str
    method: str
    revision: int
    stale: bool
    valid: bool  # the Ed25519 seal verifies
    created_at: datetime


class Counts(Schema):
    done: int
    total: int


class CanOut(Schema):
    manage: bool
    record: bool
    run: bool
    chair: bool
    sign: bool
    comment: bool


class MeetingBrief(Schema):
    id: UUID
    subject_id: UUID
    title: str
    kind: str
    status: str
    location: str
    starts_at: datetime | None
    ends_at: datetime | None
    project_id: UUID | None
    customer_id: UUID | None = None  # only set when the caller is a member of that customer file
    customer_name: str | None = None
    creator_id: int
    my_role: str | None
    attendee_count: int
    resolutions: Counts
    label_ids: list[int]
    unseen: bool
    revision: int
    updated_at: datetime


class MeetingOut(MeetingBrief):
    description: TextIn
    creator: UserRef
    attendees: list[AttendeeOut]
    resolution_items: list[ResolutionOut]
    signatures: list[SignatureOut]
    template_id: int | None
    content_hash: str
    all_signed: bool
    can: CanOut
    created_at: datetime


class SmsOut(Schema):
    sent: int
    without_phone: int


class RemindOut(Schema):
    reminders: int
