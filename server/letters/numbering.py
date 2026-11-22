"""Secretariat numbers: `{jalali_year}/{seq:04d}`, one sequence per kind and Jalali year, handed out under a row lock."""
from datetime import datetime

from django.db import transaction
from django.db.models import Max
from django.utils import timezone

from workspace.jalali import to_jalali
from workspace.recurrence import TEHRAN

from .models import Letter, NumberSequence


def _now() -> datetime:
    return timezone.now()


def current_jalali_year() -> int:
    return to_jalali(_now().astimezone(TEHRAN).date())[0]


def format_number(year: int, seq: int) -> str:
    return f"{year}/{seq:04d}"


@transaction.atomic
def next_number(kind: str, year: int | None = None) -> tuple[int, int, str]:
    """(jalali_year, seq, number). Call inside the transaction that stores the entry, so a failure gives it back."""
    year = year or current_jalali_year()
    NumberSequence.objects.get_or_create(kind=kind, jalali_year=year)
    row = NumberSequence.objects.select_for_update().get(kind=kind, jalali_year=year)
    row.last += 1
    row.save(update_fields=["last"])
    return year, row.last, format_number(year, row.last)


@transaction.atomic
def next_letter_no() -> int:
    """Global `Letter.no`: a locked counter row (year 0), never below the current max, so concurrent creates cannot collide."""
    NumberSequence.objects.get_or_create(kind="letterno", jalali_year=0)
    row = NumberSequence.objects.select_for_update().get(kind="letterno", jalali_year=0)
    row.last = max(row.last, Letter.objects.aggregate(m=Max("no"))["m"] or 0) + 1
    row.save(update_fields=["last"])
    return row.last
