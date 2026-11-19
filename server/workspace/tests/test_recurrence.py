from datetime import date, datetime, timedelta, timezone

import pytest

from workspace import jalali
from workspace.recurrence import TEHRAN, RuleError, clean_rule, next_occurrence


def tehran(y, m, d, h=9, mi=0):
    return datetime(y, m, d, h, mi, tzinfo=TEHRAN)


def local(dt):
    return dt.astimezone(TEHRAN)


def jdate(dt):
    return jalali.to_jalali(local(dt).date())


# --- Jalali conversion ---------------------------------------------------------------------------------------


def test_nowruz_anchor():
    assert jalali.to_gregorian(1405, 1, 1) == date(2026, 3, 21)
    assert jalali.to_jalali(date(2026, 3, 21)) == (1405, 1, 1)
    assert jalali.to_jalali(date(2025, 3, 20)) == (1403, 12, 30)


def test_leap_years():
    assert [y for y in range(1395, 1420) if jalali.is_leap(y)] == [1395, 1399, 1403, 1408, 1412, 1416]
    assert jalali.month_length(1403, 12) == 30 and jalali.month_length(1408, 12) == 30
    assert jalali.month_length(1404, 12) == 29 and jalali.month_length(1405, 12) == 29
    assert [jalali.month_length(1404, m) for m in (1, 6, 7, 11)] == [31, 31, 30, 30]


def test_round_trip_and_continuity_over_decades():
    day, previous = date(2000, 1, 1), None
    for i in range(365 * 60):
        current = day + timedelta(days=i)
        jy, jm, jd = jalali.to_jalali(current)
        assert jalali.to_gregorian(jy, jm, jd) == current
        if previous:
            py, pm, pd = previous
            rollover = (py, pm + 1) if pm < 12 else (py + 1, 1)
            assert (jy, jm, jd) == (py, pm, pd + 1) or (
                jd == 1 and pd == jalali.month_length(py, pm) and (jy, jm) == rollover)
        previous = (jy, jm, jd)


def test_invalid_jalali_dates_are_rejected():
    for bad in ((1404, 12, 30), (1404, 13, 1), (1404, 7, 31)):
        with pytest.raises(ValueError):
            jalali.to_gregorian(*bad)


# --- daily ------------------------------------------------------------------------------------------------------


def test_daily_next_day_same_wall_time():
    nxt = next_occurrence({"freq": "daily", "interval": 1}, tehran(2026, 3, 21), tehran(2026, 3, 21))
    assert local(nxt) == tehran(2026, 3, 22) and nxt.tzinfo == timezone.utc


def test_daily_is_strictly_after_and_interval_phase_holds():
    rule = {"freq": "daily", "interval": 3}
    anchor = tehran(2026, 5, 1)
    assert local(next_occurrence(rule, anchor, tehran(2026, 5, 3, 23, 59))) == tehran(2026, 5, 4)
    assert local(next_occurrence(rule, anchor, tehran(2026, 5, 4))) == tehran(2026, 5, 7)
    assert local(next_occurrence(rule, anchor, tehran(2026, 5, 1, 8, 0))) == tehran(2026, 5, 1)  # same day, ahead


def test_daily_across_the_tehran_midnight_boundary():
    anchor = tehran(2026, 5, 1, 0, 30)  # 21:00 UTC the day before
    nxt = next_occurrence({"freq": "daily", "interval": 1}, anchor, datetime(2026, 5, 1, 21, 0, tzinfo=timezone.utc))
    assert local(nxt) == tehran(2026, 5, 3, 0, 30)  # 00:30 on May 2 is not strictly after


# --- weekly -----------------------------------------------------------------------------------------------------


def test_weekly_picks_the_next_listed_weekday():
    # 2026-03-21 is a Saturday (index 0). Monday = 2, Wednesday = 4.
    rule = {"freq": "weekly", "interval": 1, "weekdays": [2, 4]}
    anchor = tehran(2026, 3, 21)
    assert local(next_occurrence(rule, anchor, anchor)) == tehran(2026, 3, 23)
    assert local(next_occurrence(rule, anchor, tehran(2026, 3, 23))) == tehran(2026, 3, 25)
    assert local(next_occurrence(rule, anchor, tehran(2026, 3, 25))) == tehran(2026, 3, 30)


def test_weekly_interval_two_skips_a_week_and_week_starts_saturday():
    rule = {"freq": "weekly", "interval": 2, "weekdays": [0, 6]}  # Saturday and Friday
    anchor = tehran(2026, 3, 21)  # Saturday
    first = local(next_occurrence(rule, anchor, anchor))
    assert first == tehran(2026, 3, 27)  # Friday of the same Saturday-based week
    assert local(next_occurrence(rule, anchor, first)) == tehran(2026, 4, 4)  # two weeks later, not 2026-03-28


def test_weekly_defaults_to_the_anchor_weekday():
    anchor = tehran(2026, 3, 24)  # Tuesday
    assert local(next_occurrence({"freq": "weekly", "interval": 1}, anchor, anchor)) == tehran(2026, 3, 31)


def test_weekly_first_occurrence_never_precedes_the_anchor():
    rule = {"freq": "weekly", "interval": 1, "weekdays": [0]}  # Saturdays only
    anchor = tehran(2026, 3, 24)  # Tuesday
    assert local(next_occurrence(rule, anchor, tehran(2026, 3, 1))) == tehran(2026, 3, 28)


# --- monthly_jalali ---------------------------------------------------------------------------------------------


def test_monthly_same_day_next_month():
    anchor = tehran(2026, 3, 21)  # 1405-01-01
    assert jdate(next_occurrence({"freq": "monthly_jalali", "interval": 1}, anchor, anchor)) == (1405, 2, 1)


def test_monthly_clamps_day_31_to_month_length():
    rule = {"freq": "monthly_jalali", "interval": 1, "day": 31}
    anchor = tehran(2026, 8, 22)  # 1405-05-31
    assert jdate(anchor) == (1405, 5, 31)
    current, seen = anchor, []
    for _ in range(8):
        current = local(next_occurrence(rule, current, current))
        seen.append(jdate(current))
    assert seen == [(1405, 6, 31), (1405, 7, 30), (1405, 8, 30), (1405, 9, 30), (1405, 10, 30), (1405, 11, 30),
                    (1405, 12, 29), (1406, 1, 31)]


def test_monthly_esfand_has_30_days_in_leap_years_only():
    rule = {"freq": "monthly_jalali", "interval": 1, "day": 30}
    for year, expected in ((1403, (1403, 12, 30)), (1404, (1404, 12, 29)), (1408, (1408, 12, 30))):
        g = jalali.to_gregorian(year, 11, 30)
        start = tehran(g.year, g.month, g.day)
        assert jdate(start) == (year, 11, 30)
        assert jdate(next_occurrence(rule, start, start)) == expected


def test_monthly_interval_keeps_phase_and_time():
    rule = {"freq": "monthly_jalali", "interval": 6, "day": 15}
    anchor = tehran(2026, 3, 5, 14, 15)  # 1404-12-14: day 15 still comes this month
    first = next_occurrence(rule, anchor, anchor)
    second = next_occurrence(rule, first, first)
    months = lambda dt: jdate(dt)[0] * 12 + jdate(dt)[1]  # noqa: E731
    assert months(first) - months(anchor) == 0 and months(second) - months(first) == 6
    assert jdate(first)[2] == 15 and (local(first).hour, local(first).minute) == (14, 15)


def test_monthly_never_returns_the_same_or_earlier_moment():
    rule = {"freq": "monthly_jalali", "interval": 1, "day": 15}
    anchor = tehran(2026, 4, 5)
    for offset in range(0, 400, 7):
        after = anchor + timedelta(days=offset, hours=3)
        assert next_occurrence(rule, anchor, after) > after


# --- validation -------------------------------------------------------------------------------------------------


@pytest.mark.parametrize("rule", [
    {"freq": "yearly", "interval": 1}, {"freq": "daily", "interval": 0}, {"freq": "daily", "interval": True},
    {"freq": "daily", "interval": 1000}, {"freq": "weekly", "interval": 1, "weekdays": []},
    {"freq": "weekly", "interval": 1, "weekdays": [7]}, {"freq": "monthly_jalali", "interval": 1, "day": 32},
    {"freq": "monthly_jalali", "interval": 1, "day": 0}, {},
])
def test_invalid_rules_raise(rule):
    with pytest.raises(RuleError):
        clean_rule(rule, tehran(2026, 3, 21))


def test_clean_rule_fills_defaults():
    anchor = tehran(2026, 3, 24)  # Tuesday 1405-01-04
    assert clean_rule({"freq": "weekly"}, anchor) == {"freq": "weekly", "interval": 1, "weekdays": [3]}
    assert clean_rule({"freq": "monthly_jalali"}, anchor) == {"freq": "monthly_jalali", "interval": 1, "day": 4}
    assert clean_rule({"freq": "daily", "interval": 2, "day": 9}, anchor) == {"freq": "daily", "interval": 2}


def test_naive_datetimes_are_refused():
    with pytest.raises(RuleError):
        next_occurrence({"freq": "daily"}, datetime(2026, 3, 21, 9), tehran(2026, 3, 21))
