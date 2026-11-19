"""Monitoring dashboards (advanced plan), mounted at /api/monitor. `/me` is open to everyone; every other route is 404
unless the caller holds `monitor.view` (finance and sales also need their own permission and an enabled module).
Only counts and identifying briefs are returned, never decrypted content."""
from datetime import date

from django.core.exceptions import ValidationError
from ninja import Field, Query, Router, Schema
from ninja.errors import HttpError

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, user_of
from accounts.models import User
from finance import reports as finance_reports, rules as finance_rules
from sales import rules as sales_rules, summary as sales_summary
from workspace import registry
from workspace.monitor import PERMISSION

from . import customers_report, me, meetings_report, members, overview, projects, tasks_report
from .period import BUCKETS, CALENDARS, Period, resolve

router = Router(tags=["monitor"], auth=BearerAuth())
YEAR_BUCKET_DAYS = 1100  # finance buckets switch from months to years past about three years


class PeriodQ(Schema):
    period: str = ""  # week | month | quarter | year (rolling window ending at `to`)
    from_: date | None = Field(None, alias="from")
    to: date | None = None
    calendar: str = "gregorian"  # gregorian | jalali, used for month buckets
    bucket: str = "day"  # day | week | month


def _period(q: PeriodQ) -> Period:
    if q.calendar not in CALENDARS or q.bucket not in BUCKETS:
        raise HttpError(422, "Unknown calendar or bucket")
    return resolve(q.from_, q.to, q.period)


def _holder(request) -> User:
    user = user_of(request)
    if not user.has_grant(PERMISSION):
        raise HttpError(404, "Not found")
    return user


def _module(request, code: str) -> User:
    user = _holder(request)
    registry.require_module(code)
    return user


@router.get("/me", response={200: dict, 422: Detail})
def my_numbers(request, q: Query[PeriodQ]):
    return me.build(user_of(request), _period(q))


@router.get("/overview", response={200: dict, 404: Detail, 422: Detail})
def get_overview(request, q: Query[PeriodQ]):
    user = _holder(request)
    return overview.build(user, _period(q), q.bucket, q.calendar)


@router.get("/projects", response={200: dict, 404: Detail, 422: Detail})
def get_projects(request, sort: str = "last_done", include_archived: bool = False):
    _module(request, "projects")
    registry.require_module("tasks")
    if sort not in projects.SORTS:
        raise HttpError(422, f"sort must be one of {', '.join(projects.SORTS)}")
    return projects.report(sort, include_archived)


@router.get("/tasks", response={200: dict, 404: Detail, 422: Detail})
def get_tasks(request, project: str = "", label: int | None = None, person: int | None = None, customer: str = "",
              limit: int = 50, offset: int = 0, printable: bool = False):
    _module(request, "tasks")
    try:
        rows = tasks_report.filtered(project, label, person, customer)
        return tasks_report.report(rows, limit, offset, printable)
    except (ValueError, TypeError, ValidationError) as exc:  # malformed uuid in a filter
        raise HttpError(422, "Invalid filter") from exc


@router.get("/meetings", response={200: dict, 404: Detail, 422: Detail})
def get_meetings(request, q: Query[PeriodQ], project: str = "", project_id: str = "", limit: int = 50,
                 offset: int = 0):
    _module(request, "meetings")
    try:
        return meetings_report.report(_period(q), project, project_id, limit, offset)
    except (ValueError, TypeError, ValidationError) as exc:
        raise HttpError(422, "Invalid filter") from exc


@router.get("/members", response={200: dict, 404: Detail, 422: Detail})
def get_members(request, q: Query[PeriodQ], sort: str = "done", limit: int = 100, offset: int = 0):
    _holder(request)
    if sort not in members.SORTS:
        raise HttpError(422, f"sort must be one of {', '.join(members.SORTS)}")
    return members.performance(_period(q), sort, limit, offset)


@router.get("/online", response={200: dict, 404: Detail})
def get_online(request, history_of: int | None = None):
    _holder(request)
    return members.online(history_of)


@router.get("/customers", response={200: dict, 404: Detail, 422: Detail})
def get_customers(request, q: Query[PeriodQ], limit: int = 50, offset: int = 0):
    _module(request, "crm")
    return customers_report.report(_period(q), limit, offset)


@router.get("/finance", response={200: dict, 404: Detail, 422: Detail})
def get_finance(request, q: Query[PeriodQ]):
    user = _module(request, "finance")
    if not finance_rules.holds(user):
        raise HttpError(404, "Not found")
    period = _period(q)
    rows = finance_reports.with_effective_date(finance_rules.visible_docs(user)).filter(
        effective_date__gte=period.first, effective_date__lte=period.last)
    group = "year" if (period.last - period.first).days > YEAR_BUCKET_DAYS else "month"
    try:
        buckets = finance_reports.buckets(rows, period.first, period.last, q.calendar, group)
    except ValueError as exc:
        raise HttpError(422, str(exc)) from exc
    return {**period.header(), "calendar": q.calendar, "group_by": group,
            "totals": finance_reports.totals(rows), "buckets": buckets}


@router.get("/sales", response={200: dict, 404: Detail})
def get_sales(request):
    user = _module(request, "sales")
    if not sales_rules.holds(user):
        raise HttpError(404, "Not found")
    return sales_summary.summarize(sales_rules.visible_leads(user))
