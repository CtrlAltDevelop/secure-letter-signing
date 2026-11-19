"""Reminders on any subject the caller can see. Only the owner of a reminder can see or deactivate it."""
from datetime import datetime
from typing import Any
from uuid import UUID

from ninja import Field, Router, Schema

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, user_of

from . import reminders
from .access import access_to
from .models import Reminder

router = Router(tags=["workspace"], auth=BearerAuth())


class RuleIn(Schema):
    freq: str = Field(pattern="^(daily|weekly|monthly_jalali)$")
    interval: int = Field(1, ge=1, le=365)
    weekdays: list[int] | None = Field(None, max_length=7)
    day: int | None = Field(None, ge=1, le=31)


class ReminderIn(Schema):
    at: datetime
    rule: RuleIn | None = None


class ReminderOut(Schema):
    id: int
    subject_id: UUID
    at: datetime
    rule: dict[str, Any] | None
    last_fired_at: datetime | None


def out(r: Reminder) -> ReminderOut:
    return ReminderOut(id=r.id, subject_id=r.subject_id, at=r.next_at, rule=r.rule, last_fired_at=r.last_fired_at)


@router.get("/subjects/{uuid:subject_id}/reminders", response={200: list[ReminderOut], 404: Detail})
def list_mine(request, subject_id: UUID):
    user = user_of(request)
    return [out(r) for r in reminders.mine(user, access_to(user, subject_id, "see").subject)]


@router.post("/subjects/{uuid:subject_id}/reminders", response={201: ReminderOut, 404: Detail, 422: Detail})
def add(request, subject_id: UUID, data: ReminderIn):
    user = user_of(request)
    acc = access_to(user, subject_id, "see")
    rule = data.rule.model_dump(exclude_none=True) if data.rule else None
    return 201, out(reminders.create(user, acc.subject, data.at, rule))


@router.delete("/reminders/{int:reminder_id}", response={204: None, 404: Detail})
def deactivate(request, reminder_id: int):
    reminders.deactivate(user_of(request), reminder_id)
    return 204, None
