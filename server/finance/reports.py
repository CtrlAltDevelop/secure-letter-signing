"""Aggregation over finance documents. Void documents never count.

Per document: a confirmed one counts under `confirmed_*` at its `date`; a pending one (cheque/probable) counts under
`probable_*` at its `due_date` (its `date` when it has none), and also under `overdue_*` when `due_date` is before today.
"""
from datetime import date, datetime, timedelta, timezone
from typing import Any

from django.db.models import Case, DateField, F, Q, QuerySet, When

from workspace import periods
from workspace.recurrence import TEHRAN

from .models import FinanceDoc

CATEGORIES = ("confirmed_receipts", "confirmed_payments", "probable_receipts", "probable_payments",
              "overdue_receipts", "overdue_payments")
EFFECTIVE_DATE = Case(When(Q(status=FinanceDoc.PENDING, due_date__isnull=False), then=F("due_date")),
                      default=F("date"), output_field=DateField())


def today() -> date:
    return datetime.now(timezone.utc).astimezone(TEHRAN).date()


def with_effective_date(rows: QuerySet[FinanceDoc]) -> QuerySet[FinanceDoc]:
    return rows.annotate(effective_date=EFFECTIVE_DATE)


def empty_stats() -> dict[str, Any]:
    return {**{c: 0 for c in CATEGORIES}, "net": 0, "projected_net": 0, "counts": {c: 0 for c in CATEGORIES}}


def _categories(direction: str, status: str, due: date | None, now: date) -> list[str]:
    suffix = "receipts" if direction == FinanceDoc.RECEIPT else "payments"
    if status == FinanceDoc.CONFIRMED:
        return [f"confirmed_{suffix}"]
    out = [f"probable_{suffix}"]
    if due is not None and due < now:
        out.append(f"overdue_{suffix}")
    return out


def _finish(stats: dict[str, Any]) -> dict[str, Any]:
    stats["net"] = stats["confirmed_receipts"] - stats["confirmed_payments"]
    stats["projected_net"] = stats["net"] + stats["probable_receipts"] - stats["probable_payments"]
    return stats


def add_row(stats: dict[str, Any], direction: str, status: str, amount: int, due: date | None, now: date) -> None:
    for name in _categories(direction, status, due, now):
        stats[name] += amount
        stats["counts"][name] += 1


def totals(rows: QuerySet[FinanceDoc]) -> dict[str, Any]:
    """Stats over `rows` with no bucketing."""
    now, stats = today(), empty_stats()
    for direction, status, amount, due in rows.exclude(status=FinanceDoc.VOIDED).values_list(
            "direction", "status", "amount", "due_date"):
        add_row(stats, direction, status, amount, due, now)
    return _finish(stats)


def range_of(rows: QuerySet[FinanceDoc], start: date | None, end: date | None) -> tuple[date, date] | None:
    """The report range: given bounds, else the span of the data; None when there is nothing to report."""
    if start and end:
        return start, end
    dates = list(rows.values_list("effective_date", flat=True))
    if not dates and not (start or end):
        return None
    first, last = start or min(dates, default=end), end or max(dates, default=start)
    return first, last


def buckets(rows: QuerySet[FinanceDoc], start: date | None, end: date | None, cal: str,
            group_by: str) -> list[dict[str, Any]]:
    """One entry per period between start and end (gaps filled with zeros), ready for JSON."""
    rows = with_effective_date(rows.exclude(status=FinanceDoc.VOIDED))
    if start:
        rows = rows.filter(effective_date__gte=start)
    if end:
        rows = rows.filter(effective_date__lte=end)
    span = range_of(rows, start, end)
    if span is None:
        return []
    keys = periods.keys_between(span[0], span[1], cal, group_by)
    now, stats = today(), {k: empty_stats() for k in keys}
    for direction, status, amount, due, day in rows.values_list(
            "direction", "status", "amount", "due_date", "effective_date"):
        add_row(stats[periods.key_of(day, cal, group_by)], direction, status, amount, due, now)
    return [_bucket(k, cal, _finish(stats[k])) for k in keys]


def _bucket(key: periods.Key, cal: str, stats: dict[str, Any]) -> dict[str, Any]:
    start, end = periods.bounds(key, cal)
    return {"period": periods.label(key), "start": start, "end": end, **periods.jalali_fields(key, cal), **stats}


def sum_buckets(items: list[dict[str, Any]]) -> dict[str, Any]:
    stats = empty_stats()
    for item in items:
        for name in CATEGORIES:
            stats[name] += item[name]
            stats["counts"][name] += item["counts"][name]
    return _finish(stats)


def default_chart_range() -> tuple[date, date]:
    now = today()
    return now - timedelta(days=365), now
