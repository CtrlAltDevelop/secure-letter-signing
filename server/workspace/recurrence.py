"""Reminder recurrence: the next occurrence of a rule strictly after a moment, in Asia/Tehran with Jalali months.

Pure functions. A rule is `{freq: daily|weekly|monthly_jalali, interval: int >= 1, weekdays?: [0-6], day?: 1-31}`;
weekdays count from Saturday = 0 (Friday = 6). The time of day comes from the anchor (the occurrence being advanced).
Tehran has had no daylight saving since 2022; wall-clock times are mapped through the zone rules anyway.
"""
from datetime import date, datetime, time, timedelta, timezone
from typing import Any
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from . import jalali

try:
    TEHRAN = ZoneInfo("Asia/Tehran")
except ZoneInfoNotFoundError:  # no tz database installed: Tehran is a fixed +03:30 today
    TEHRAN = timezone(timedelta(hours=3, minutes=30), "Asia/Tehran")

FREQS = ("daily", "weekly", "monthly_jalali")
MAX_INTERVAL = 365
WEEK = 7


class RuleError(ValueError):
    """The rule is not valid."""


def saturday_index(day: date) -> int:
    """0 = Saturday .. 6 = Friday."""
    return (day.weekday() + 2) % WEEK


def _is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def clean_rule(rule: dict[str, Any], anchor: datetime) -> dict[str, Any]:
    """Validated, complete form of `rule`: weekly gets its weekdays, monthly its day (both default from the anchor)."""
    freq, interval = rule.get("freq"), rule.get("interval", 1)
    if freq not in FREQS:
        raise RuleError("freq must be daily, weekly or monthly_jalali")
    if not _is_int(interval) or not 1 <= interval <= MAX_INTERVAL:
        raise RuleError(f"interval must be an integer from 1 to {MAX_INTERVAL}")
    local = anchor.astimezone(TEHRAN)
    out: dict[str, Any] = {"freq": freq, "interval": interval}
    if freq == "weekly":
        out["weekdays"] = _weekdays(rule.get("weekdays"), saturday_index(local.date()))
    if freq == "monthly_jalali":
        out["day"] = _month_day(rule.get("day"), jalali.to_jalali(local.date())[2])
    return out


def _weekdays(raw: Any, default: int) -> list[int]:
    if raw is None:
        return [default]
    if not (isinstance(raw, list) and raw and all(_is_int(d) and 0 <= d <= 6 for d in raw)):
        raise RuleError("weekdays must be a non-empty list of 0-6 (Saturday = 0)")
    return sorted(set(raw))


def _month_day(raw: Any, default: int) -> int:
    if raw is None:
        return default
    if not _is_int(raw) or not 1 <= raw <= 31:
        raise RuleError("day must be 1-31")
    return raw


def _at(day: date, clock: time) -> datetime:
    return datetime.combine(day, clock, tzinfo=TEHRAN)


def _clock(moment: datetime) -> time:
    return moment.timetz().replace(tzinfo=None)


def _daily(interval: int, anchor: datetime, after: datetime) -> datetime:
    first, clock = anchor.date(), _clock(anchor)
    steps = max((after.date() - first).days // interval, 0)
    while True:
        candidate = _at(first + timedelta(days=steps * interval), clock)
        if candidate > after:
            return candidate
        steps += 1


def _weekly(interval: int, weekdays: list[int], anchor: datetime, after: datetime) -> datetime:
    clock = _clock(anchor)
    anchor_week = anchor.date().toordinal() - saturday_index(anchor.date())
    start = max(after.date(), anchor.date())
    week = start.toordinal() - saturday_index(start)
    week -= (week - anchor_week) // WEEK % interval * WEEK  # back to a week of the anchor's phase
    while True:
        for wd in weekdays:
            candidate = _at(date.fromordinal(week + wd), clock)
            if candidate > after and candidate.date() >= anchor.date():
                return candidate
        week += interval * WEEK


def _monthly(interval: int, day: int, anchor: datetime, after: datetime) -> datetime:
    clock = _clock(anchor)
    ay, am, _ = jalali.to_jalali(anchor.date())
    sy, sm, _ = jalali.to_jalali(max(after.date(), anchor.date()))
    index, first = sy * 12 + sm - 1, ay * 12 + am - 1
    index -= (index - first) % interval  # back to a month of the anchor's phase
    while True:
        year, month = divmod(index, 12)
        length = jalali.month_length(year, month + 1)
        candidate = _at(jalali.to_gregorian(year, month + 1, min(day, length)), clock)
        if candidate > after and candidate.date() >= anchor.date():
            return candidate
        index += interval


def next_occurrence(rule: dict[str, Any], anchor: datetime, after: datetime) -> datetime:
    """The first occurrence of `rule` strictly after `after`, as UTC. `anchor` is an occurrence (sets time and phase)."""
    if anchor.tzinfo is None or after.tzinfo is None:
        raise RuleError("anchor and after must be timezone-aware")
    full = clean_rule(rule, anchor)
    local_anchor, local_after = anchor.astimezone(TEHRAN), after.astimezone(TEHRAN)
    if full["freq"] == "daily":
        found = _daily(full["interval"], local_anchor, local_after)
    elif full["freq"] == "weekly":
        found = _weekly(full["interval"], full["weekdays"], local_anchor, local_after)
    else:
        found = _monthly(full["interval"], full["day"], local_anchor, local_after)
    return found.astimezone(timezone.utc)
