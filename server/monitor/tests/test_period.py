from datetime import date

from monitor.period import preset_start


def test_presets_start_on_jalali_boundaries():
    day = date(2026, 11, 19)  # Thursday, 28 Aban 1405
    assert preset_start("week", day) == date(2026, 11, 14)  # Saturday
    assert preset_start("month", day) == date(2026, 10, 23)  # 1 Aban
    assert preset_start("quarter", day) == date(2026, 9, 23)  # 1 Mehr
    assert preset_start("year", day) == date(2026, 3, 21)  # 1 Farvardin 1405
