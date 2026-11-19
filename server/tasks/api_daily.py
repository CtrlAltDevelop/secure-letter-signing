"""`GET /tasks/done-daily?date=YYYY-MM-DD`: the caller's own done-list for printing."""
from datetime import date as Date, datetime

from ninja import Router, Schema

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, user_of
from workspace import registry
from workspace.recurrence import TEHRAN

from . import daily

router = Router(tags=["tasks"], auth=BearerAuth())


class DoneItem(Schema):
    task_id: str
    subject_id: str
    title: str
    project_id: str | None
    project_name: str
    at: datetime


class DoneDaily(Schema):
    date: Date
    groups: dict[str, list[DoneItem]]
    total: int


@router.get("/done-daily", response={200: DoneDaily, 422: Detail})
def done_daily(request, date: Date | None = None):
    registry.require_module("tasks")
    day = date or datetime.now(TEHRAN).date()
    return daily.done_on(user_of(request), day)
