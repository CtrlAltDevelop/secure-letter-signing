"""Reporting periods: whole Asia/Tehran days, `[start, end)` as aware datetimes, default last 30 days, max 366."""
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta

from django.db.models import Count, QuerySet
from django.db.models.functions import TruncDate
from django.utils import timezone
from ninja.errors import HttpError

from workspace import periods
from workspace.recurrence import TEHRAN

DEFAULT_DAYS = 30
MAX_DAYS = 366


@dataclass(frozen=True)
class Period:
    first: date
    last: date

    @property
    def start(self) -> datetime:
        return datetime.combine(self.first, time.min, tzinfo=TEHRAN)

    @property
    def end(self) -> datetime:
        return datetime.combine(self.last + timedelta(days=1), time.min, tzinfo=TEHRAN)

    def days(self) -> list[date]:
        return [self.first + timedelta(days=i) for i in range((self.last - self.first).days + 1)]

    def header(self) -> dict[str, str]:
        return {"from": self.first.isoformat(), "to": self.last.isoformat()}


def today() -> date:
    return timezone.now().astimezone(TEHRAN).date()


def today_bounds() -> tuple[datetime, datetime]:
    day = Period(today(), today())
    return day.start, day.end


PRESET_DAYS = {"week": 7, "month": 30, "quarter": 90, "year": 365}  # rolling windows ending at `to` (default today)


def resolve(first: date | None, last: date | None, preset: str = "") -> Period:
    if preset and preset not in PRESET_DAYS:
        raise HttpError(422, "period must be week, month, quarter or year")
    last = last or today()
    days = PRESET_DAYS.get(preset, DEFAULT_DAYS)
    first = first or last - timedelta(days=days - 1)
    if last < first:
        raise HttpError(422, "to must not be before from")
    if (last - first).days + 1 > MAX_DAYS:
        raise HttpError(422, f"The period is limited to {MAX_DAYS} days")
    return Period(first, last)


def from_bounds(start: datetime, end: datetime) -> Period:
    """The inverse of `start`/`end`, for module callbacks that receive datetimes."""
    return Period(start.astimezone(TEHRAN).date(), (end.astimezone(TEHRAN) - timedelta(microseconds=1)).date())


def daily(rows: QuerySet, field: str, period: Period, agg=None) -> list[dict]:
    """`[{date, value}]` for every day of the period (zeros included): rows counted by the Tehran day of `field`."""
    bounded = rows.filter(**{f"{field}__gte": period.start, f"{field}__lt": period.end})
    grouped = (bounded.annotate(day=TruncDate(field, tzinfo=TEHRAN)).order_by().values("day")
               .annotate(value=agg or Count("pk")))
    found = {row["day"]: row["value"] for row in grouped}
    return [{"date": d.isoformat(), "value": found.get(d, 0)} for d in period.days()]


def total(series: list[dict]) -> int:
    return sum(point["value"] for point in series)


BUCKETS = ("day", "week", "month")
CALENDARS = periods.CALENDARS


def bucketize(series: list[dict], bucket: str, calendar: str) -> list[dict]:
    """Sum a daily `[{date, value}]` series into `day`, 7-day `week` or calendar `month` (Gregorian or Jalali) buckets."""
    if bucket == "day":
        return series
    out: dict = {}
    for i, point in enumerate(series):
        day = date.fromisoformat(point["date"])
        if bucket == "week":
            key, label = i // 7, point["date"]
        else:
            key = periods.key_of(day, calendar, "month")
            label = periods.label(key)
        row = out.setdefault(key, {"date": point["date"], "label": label, "value": 0})
        row["value"] += point["value"]
    return list(out.values())
