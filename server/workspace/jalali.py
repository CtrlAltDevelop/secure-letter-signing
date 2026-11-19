"""Jalali (Solar Hijri) <-> Gregorian conversion: the 33-year cycle algorithm of jalaali-js, valid for 1 .. 3177.

Pure functions on `datetime.date`; no time zones here. Anchor: 1405-01-01 = 2026-03-21.
"""
from datetime import date

JDN_OFFSET = 1721425  # Julian day number of a date = date.toordinal() + JDN_OFFSET
MIN_YEAR, MAX_YEAR = -60, 3176
_BREAKS = (-61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181, 1210, 1635, 2060, 2097, 2192, 2262, 2324, 2394, 2456, 3178)


def _check_year(jy: int) -> None:
    if not MIN_YEAR <= jy <= MAX_YEAR:
        raise ValueError(f"Invalid Jalali year {jy}")


def _cal(jy: int) -> tuple[int, int, int]:
    """(leap, gregorian year of Nowruz, day of March of Nowruz); `leap` is 0 in a leap year, else 1..3 (years since)."""
    _check_year(jy)
    gy = jy + 621
    leap_j = -14
    jp = _BREAKS[0]
    jump = 0
    for jm in _BREAKS[1:]:
        jump = jm - jp
        if jy < jm:
            break
        leap_j += jump // 33 * 8 + jump % 33 // 4
        jp = jm
    n = jy - jp
    leap_j += n // 33 * 8 + (n % 33 + 3) // 4
    if jump % 33 == 4 and jump - n == 4:
        leap_j += 1
    leap_g = gy // 4 - (gy // 100 + 1) * 3 // 4 - 150
    march = 20 + leap_j - leap_g
    if jump - n < 6:
        n = n - jump + (jump + 4) // 33 * 33
    x = (n + 1) % 33 - 1
    leap = 4 if x == -1 else x % 4
    return leap, gy, march


def is_leap(jy: int) -> bool:
    return _cal(jy)[0] == 0


def month_length(jy: int, jm: int) -> int:
    """Days in a Jalali month: 31 for Farvardin..Shahrivar, 30 for Mehr..Bahman, 29 (30 in leap years) for Esfand."""
    if not 1 <= jm <= 12:
        raise ValueError(f"Invalid Jalali month {jm}")
    if jm <= 6:
        return 31
    if jm <= 11:
        return 30
    return 30 if is_leap(jy) else 29


def to_gregorian(jy: int, jm: int, jd: int) -> date:
    if not 1 <= jd <= month_length(jy, jm):
        raise ValueError(f"Invalid Jalali date {jy}-{jm}-{jd}")
    _, gy, march = _cal(jy)
    nowruz = date(gy, 3, march).toordinal()
    return date.fromordinal(nowruz + (jm - 1) * 31 - jm // 7 * (jm - 7) + jd - 1)


def to_jalali(day: date) -> tuple[int, int, int]:
    """(year, month, day) of a Gregorian date."""
    jy = day.year - 621
    leap, gy, march = _cal(jy)
    k = day.toordinal() - date(gy, 3, march).toordinal()
    if k < 0:  # before this year's Nowruz: belongs to the previous Jalali year
        jy -= 1
        leap, gy, march = _cal(jy)
        k = day.toordinal() - date(gy, 3, march).toordinal()
    elif k >= 366:  # already past the next Nowruz
        jy += 1
        leap, gy, march = _cal(jy)
        k = day.toordinal() - date(gy, 3, march).toordinal()
    if k <= 185:
        return jy, 1 + k // 31, k % 31 + 1
    k -= 186
    return jy, 7 + k // 30, k % 30 + 1
