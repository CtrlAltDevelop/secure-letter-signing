"""Calendar periods (Gregorian or Jalali months and years) for reports.

A period key is `(year, month)`; year periods use month 0. Bounds are Gregorian dates, inclusive.
"""
import calendar as gregorian
from datetime import date

from . import jalali

GREGORIAN, JALALI = "gregorian", "jalali"
CALENDARS = (GREGORIAN, JALALI)
GROUPS = ("month", "year")
MAX_PERIODS = 600

Key = tuple[int, int]


def key_of(day: date, cal: str, group_by: str) -> Key:
    year, month = (day.year, day.month) if cal == GREGORIAN else jalali.to_jalali(day)[:2]
    return (year, month if group_by == "month" else 0)


def bounds(key: Key, cal: str) -> tuple[date, date]:
    year, month = key
    first, last = (month or 1), (month or 12)
    if cal == GREGORIAN:
        return date(year, first, 1), date(year, last, gregorian.monthrange(year, last)[1])
    return jalali.to_gregorian(year, first, 1), jalali.to_gregorian(year, last, jalali.month_length(year, last))


def following(key: Key) -> Key:
    year, month = key
    if month == 0:
        return year + 1, 0
    return (year + 1, 1) if month == 12 else (year, month + 1)


def keys_between(start: date, end: date, cal: str, group_by: str) -> list[Key]:
    """Every period key from the one holding `start` to the one holding `end` (ValueError past MAX_PERIODS)."""
    key, last = key_of(start, cal, group_by), key_of(end, cal, group_by)
    out: list[Key] = []
    while key <= last:
        out.append(key)
        if len(out) > MAX_PERIODS:
            raise ValueError("Range too long")
        key = following(key)
    return out


def label(key: Key) -> str:
    year, month = key
    return f"{year:04d}-{month:02d}" if month else f"{year:04d}"


def jalali_fields(key: Key, cal: str) -> dict[str, int | None]:
    """`jalali_year` / `jalali_month` of a period (the month is null for year periods)."""
    start = bounds(key, cal)[0]
    jy, jm, _ = jalali.to_jalali(start)
    return {"jalali_year": jy, "jalali_month": jm if key[1] else None}
