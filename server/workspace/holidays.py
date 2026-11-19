"""Holidays: the fixed Jalali official days, seeding, and range queries. Lunar days are entered by the manager."""
from datetime import date

from workspace import jalali

from .models import Holiday

MAX_SEED_YEARS = 60
WEEKEND = [5]  # Friday; Saturday = 0 as elsewhere
# (jalali month, day, title)
FIXED_OFFICIAL: tuple[tuple[int, int, str], ...] = (
    (1, 1, "عید نوروز"), (1, 2, "عید نوروز"), (1, 3, "عید نوروز"), (1, 4, "عید نوروز"),
    (1, 12, "روز جمهوری اسلامی"), (1, 13, "روز طبیعت"),
    (3, 14, "رحلت امام خمینی"), (3, 15, "قیام ۱۵ خرداد"),
    (11, 22, "پیروزی انقلاب اسلامی"), (12, 29, "ملی شدن صنعت نفت"),
)


def seed_fixed(first_year: int, last_year: int) -> int:
    """Create the fixed official holidays for Jalali years `first_year..last_year`; returns how many were new."""
    if last_year < first_year or last_year - first_year >= MAX_SEED_YEARS:
        raise ValueError(f"year range must be 1..{MAX_SEED_YEARS} years")
    created = 0
    for year in range(first_year, last_year + 1):
        for month, day, title in FIXED_OFFICIAL:
            _, new = Holiday.objects.get_or_create(date=jalali.to_gregorian(year, month, day), title=title,
                                                   defaults={"kind": Holiday.OFFICIAL})
            created += new
    return created


def in_range(first: date, last: date, include_inactive: bool = False) -> list[Holiday]:
    rows = Holiday.objects.filter(date__gte=first, date__lte=last)
    if not include_inactive:
        rows = rows.filter(active=True)
    return list(rows.order_by("date", "id"))
