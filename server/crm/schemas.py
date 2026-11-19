from datetime import datetime
from uuid import UUID

from ninja import Field, Schema

from tasks.schemas import DescriptionIn, DescriptionOut
from workspace.schemas import UserRef

ROLE = "^(manager|member|viewer)$"
KIND = "^(person|company)$"
STATUS = "^(active|inactive|archived)$"
MANUAL_EVENT_KINDS = "^(note|call|meeting|finance|lead)$"
MAX_MEMBERS = 500


class MemberIn(Schema):
    user_id: int
    role: str = Field(pattern=ROLE)


class MemberOut(Schema):
    user: UserRef
    role: str


class CustomerIn(Schema):
    kind: str = Field("person", pattern=KIND)
    name: str = Field(min_length=1, max_length=200)
    legal_name: str = Field("", max_length=200)
    national_id: str = Field("", max_length=20)
    registration_no: str = Field("", max_length=30)
    phone: str = Field("", max_length=30)
    mobile: str = Field("", max_length=30)
    email: str = Field("", max_length=254)
    address: DescriptionIn | None = None
    notes: DescriptionIn | None = None
    status: str = Field("active", pattern=STATUS)
    members: list[MemberIn] = Field(default_factory=list, max_length=MAX_MEMBERS)  # the creator is added as manager


class CustomerPatch(Schema):
    """Only the fields present in the request change (`null` clears text fields)."""

    kind: str | None = Field(None, pattern=KIND)
    name: str | None = Field(None, min_length=1, max_length=200)
    legal_name: str | None = Field(None, max_length=200)
    national_id: str | None = Field(None, max_length=20)
    registration_no: str | None = Field(None, max_length=30)
    phone: str | None = Field(None, max_length=30)
    mobile: str | None = Field(None, max_length=30)
    email: str | None = Field(None, max_length=254)
    address: DescriptionIn | None = None
    notes: DescriptionIn | None = None
    status: str | None = Field(None, pattern=STATUS)


class CustomerBrief(Schema):
    id: UUID
    subject_id: UUID
    kind: str
    name: str
    legal_name: str
    national_id: str
    phone: str
    mobile: str
    email: str
    status: str
    owner_id: int
    my_role: str
    label_ids: list[int]
    unseen: bool
    updated_at: datetime


class CanOut(Schema):
    see: bool
    comment: bool
    label: bool
    link: bool
    event: bool
    call: bool
    edit: bool
    members: bool


class CustomerOut(CustomerBrief):
    registration_no: str
    address: DescriptionOut
    notes: DescriptionOut
    owner: UserRef
    members: list[MemberOut]
    can: CanOut
    created_at: datetime


class EventIn(Schema):
    kind: str = Field("note", pattern=MANUAL_EVENT_KINDS)
    summary: str = Field(min_length=1, max_length=2000)
    at: datetime | None = None


class EventOut(Schema):
    id: int
    kind: str
    summary: str
    at: datetime
    by: UserRef | None
    ref_subject_id: UUID | None


class CallIn(Schema):
    direction: str = Field(pattern="^(in|out)$")
    contact_name: str = Field("", max_length=150)
    summary: str = Field("", max_length=20_000)
    at: datetime | None = None
    duration_s: int = Field(0, ge=0, le=86_400)


class CallOut(Schema):
    id: int
    direction: str
    contact_name: str
    summary: str
    at: datetime
    duration_s: int
    by: UserRef


class CallToTaskIn(Schema):
    title: str | None = Field(None, min_length=1, max_length=200)
    owner_ids: list[int] = Field(default_factory=list, max_length=50)
    due_at: datetime | None = None


class ImportError_(Schema):
    row: int
    message: str


class ImportOut(Schema):
    created: int
    skipped: int
    errors: list[ImportError_]
