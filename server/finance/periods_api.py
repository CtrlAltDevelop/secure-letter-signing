"""Report endpoints' logic: summary, Jalali monthly table and chart series."""
from datetime import date
from typing import Any

from ninja.errors import HttpError

from accounts.models import User
from workspace import jalali, periods
from workspace.access import visible_labels
from workspace.models import SubjectLabel

from . import reports, rules
from .schemas import ChartOut, MonthlyOut, SummaryOut


def _labelled(user: User, label: int | None):
    rows = rules.visible_docs(user)
    if label is None:
        return rows
    ok = visible_labels(user).filter(pk=label, active=True).exists()
    tagged = SubjectLabel.objects.filter(label_id=label, active=True).values("subject_id") if ok else []
    return rows.filter(subject_id__in=tagged)


def _buckets(rows, start: date | None, end: date | None, cal: str, group_by: str) -> list[dict[str, Any]]:
    if start and end and start > end:
        raise HttpError(422, "from must not be after to")
    try:
        return reports.buckets(rows, start, end, cal, group_by)
    except ValueError as exc:
        raise HttpError(422, str(exc)) from exc


def summary(user: User, start: date | None, end: date | None, group_by: str, cal: str,
            label: int | None) -> SummaryOut:
    if group_by not in periods.GROUPS or cal not in periods.CALENDARS:
        raise HttpError(422, "group_by must be month|year and calendar gregorian|jalali")
    items = _buckets(_labelled(user, label), start, end, cal, group_by)
    return SummaryOut(calendar=cal, group_by=group_by, today=reports.today(), totals=reports.sum_buckets(items),
                      buckets=items)


def monthly(user: User, year: int) -> MonthlyOut:
    try:
        first = jalali.to_gregorian(year, 1, 1)
        last = jalali.to_gregorian(year, 12, jalali.month_length(year, 12))
    except ValueError as exc:
        raise HttpError(422, "Invalid year") from exc
    items = _buckets(rules.visible_docs(user), first, last, periods.JALALI, "month")
    months = [{"month": i["jalali_month"], **i} for i in items]
    return MonthlyOut(year=year, months=months, totals=reports.sum_buckets(items))


def chart(user: User, start: date | None, end: date | None) -> ChartOut:
    default_start, default_end = reports.default_chart_range()
    items = _buckets(rules.visible_docs(user), start or default_start, end or default_end, periods.JALALI, "month")
    points = [{"period": i["period"], "jalali_year": i["jalali_year"], "jalali_month": i["jalali_month"],
               "start": i["start"], "receipts": i["confirmed_receipts"], "payments": i["confirmed_payments"]}
              for i in items]
    return ChartOut(labels=[p["period"] for p in points], receipts=[p["receipts"] for p in points],
                    payments=[p["payments"] for p in points], points=points)
