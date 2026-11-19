"""`GET /calendar`, holidays, and the `monitor.view` overview (`GET /tasks/of/{user_id}`)."""
from datetime import date as Date, datetime
from uuid import UUID

from django.db.models import F
from django.shortcuts import get_object_or_404
from ninja import Field, Query, Router, Schema
from ninja.errors import HttpError

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, require_manager, user_of
from accounts.models import User

from . import holidays, monitor, registry, work_calendar
from .models import Holiday

router = Router(tags=["calendar"], auth=BearerAuth())
MAX_HOLIDAY_RANGE_DAYS = 800


class CalendarItem(Schema):
    kind: str
    id: str
    subject_id: str | None
    title: str
    start: datetime
    end: datetime
    all_day: bool
    status: str
    project_id: str | None
    project_name: str
    color: int
    done: bool
    owner_ids: list[int] | None = None  # team view only


class HolidayOut(Schema):
    id: int
    date: Date
    title: str
    kind: str
    active: bool


class CalendarOut(Schema):
    items: list[CalendarItem]
    holidays: list[HolidayOut]
    weekend: list[int]


class HolidayIn(Schema):
    date: Date
    title: str = Field(min_length=1, max_length=100)
    kind: str = Field("company", pattern="^(official|religious|company)$")


class HolidayPatch(Schema):
    date: Date | None = None
    title: str | None = Field(None, min_length=1, max_length=100)
    kind: str | None = Field(None, pattern="^(official|religious|company)$")
    active: bool | None = None


def _holiday_out(row: Holiday) -> HolidayOut:
    return HolidayOut(id=row.id, date=row.date, title=row.title, kind=row.kind, active=row.active)


@router.get("/calendar", response={200: CalendarOut, 403: Detail, 422: Detail})
def calendar(request, from_: datetime = Query(..., alias="from"), to: datetime = Query(...), kinds: str = "",
             project: UUID | None = None, customer: UUID | None = None, label: int | None = None,
             owner: int | None = None, team: bool = False, user: int | None = None):
    me = user_of(request)
    start, end = work_calendar.check_range(from_, to)
    query = work_calendar.Query(start, end, work_calendar.parse_kinds(kinds), project, customer, label,
                                user if team and user is not None else owner)
    if team:
        monitor.require_holder(me)
        items = work_calendar.task_items(monitor.active_tasks(), query, me, with_owners=True)
        items.sort(key=lambda i: (i["start"], i["id"]))
    else:
        items = work_calendar.items_for(me, query)
    first, last = work_calendar.tehran_days(start, end)
    return CalendarOut(items=items, holidays=[_holiday_out(h) for h in holidays.in_range(first, last)],
                       weekend=holidays.WEEKEND)


@router.get("/holidays", response={200: list[HolidayOut], 422: Detail})
def list_holidays(request, from_: Date = Query(..., alias="from"), to: Date = Query(...),
                  include_inactive: bool = False):
    me = user_of(request)
    if to < from_ or (to - from_).days > MAX_HOLIDAY_RANGE_DAYS:
        raise HttpError(422, f"to must not be before from and the range is limited to {MAX_HOLIDAY_RANGE_DAYS} days")
    rows = holidays.in_range(from_, to, include_inactive=include_inactive and me.is_manager)
    return [_holiday_out(h) for h in rows]


@router.post("/holidays", response={201: HolidayOut, 403: Detail, 409: Detail})
def create_holiday(request, data: HolidayIn):
    require_manager(request)
    row, created = Holiday.objects.get_or_create(date=data.date, title=data.title.strip(),
                                                 defaults={"kind": data.kind})
    if not created:
        if row.active:
            raise HttpError(409, "This holiday already exists")
        row.active, row.kind = True, data.kind
        row.save(update_fields=["active", "kind"])
    return 201, _holiday_out(row)


@router.patch("/holidays/{int:holiday_id}", response={200: HolidayOut, 403: Detail, 404: Detail, 409: Detail})
def update_holiday(request, holiday_id: int, data: HolidayPatch):
    require_manager(request)
    row = get_object_or_404(Holiday, pk=holiday_id)
    for field in ("date", "kind", "active"):
        value = getattr(data, field)
        if value is not None:
            setattr(row, field, value)
    if data.title is not None:
        row.title = data.title.strip()
    clash = Holiday.objects.filter(date=row.date, title=row.title).exclude(pk=row.pk).exists()
    if clash:
        raise HttpError(409, "This holiday already exists")
    row.save()
    return _holiday_out(row)


@router.get("/tasks/of/{int:user_id}", response={200: list, 403: Detail, 404: Detail, 422: Detail})
def tasks_of(request, user_id: int, box: str = "inbox", limit: int = 50, offset: int = 0):
    """`monitor.view` holders: a colleague's active tasks as briefs (titles, status, dates, owners)."""
    from tasks import queries
    from tasks.serializers import briefs

    me = user_of(request)
    monitor.require_holder(me)
    registry.require_module("tasks")
    if box not in ("inbox", "followup"):
        raise HttpError(422, "box must be inbox or followup")
    target = get_object_or_404(User, pk=user_id, is_active=True)
    rows = queries.box_of(target, monitor.active_tasks(), box).order_by(F("due_at").asc(nulls_last=True), "id")
    start = max(offset, 0)
    page = list(rows.select_related("creator")[start: start + max(min(limit, queries.MAX_LIMIT), 0)])
    out = [b.model_dump(mode="json") for b in briefs(me, page)]
    for row in out:  # the viewer's own labels and roles on someone else's task mean nothing
        row["label_ids"], row["my_roles"] = [], []
    return out
