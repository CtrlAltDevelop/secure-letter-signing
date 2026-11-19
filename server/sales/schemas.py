from datetime import datetime
from uuid import UUID

from ninja import Field, Schema

from workspace.schemas import TextBody, UserRef

MAX_VALUE = 10**15


class LeadIn(Schema):
    title: str = Field(min_length=1, max_length=200)
    value: int = Field(default=0, ge=0, le=MAX_VALUE)
    probability: int = Field(default=50, ge=0, le=100)
    customer_id: UUID | None = None
    owner_id: int | None = None  # default: the creator
    description: TextBody | None = None


class LeadPatch(Schema):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    value: int | None = Field(default=None, ge=0, le=MAX_VALUE)
    probability: int | None = Field(default=None, ge=0, le=100)
    customer_id: UUID | None = None
    owner_id: int | None = None
    description: TextBody | None = None


class LoseIn(Schema):
    reason: str = Field(min_length=1, max_length=2000)


class LeadOut(Schema):
    id: UUID
    subject_id: UUID
    customer_id: UUID | None
    customer_name: str | None
    title: str
    value: int
    probability: int
    weighted_value: int
    status: str
    owner: UserRef
    description: TextBody
    closed_at: datetime | None
    lost_reason: TextBody | None
    created_by: UserRef
    created_at: datetime
    updated_at: datetime
    label_ids: list[int]
    can_edit: bool


class SummaryOut(Schema):
    won: dict
    open: dict
    lost: dict
    by_status: dict
    by_probability: list[dict]
    won_by_month: list[dict]
    by_owner: list[dict]
