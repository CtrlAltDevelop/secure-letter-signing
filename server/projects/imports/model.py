"""Shared pieces of the project importers: limits, the parsed-row model, text cleaning and date parsing."""
import re
from dataclasses import dataclass, field
from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from ninja.errors import HttpError

from workspace import jalali

MAX_BYTES = 5 * 1024 * 1024
MAX_ROWS = 2000
MAX_CHECKLIST = 200
MAX_TITLE, MAX_ITEM, MAX_DESCRIPTION, MAX_LABEL = 200, 300, 50_000, 60
TEHRAN = ZoneInfo("Asia/Tehran")
PRIORITIES = {"low", "normal", "high", "urgent"}

_CONTROL = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")
_DIGITS = str.maketrans("۰۱۲۳۴۵۶۷۸۹"
                        "٠١٢٣٤٥٦٧٨٩", "01234567890123456789")
_JALALI = re.compile(r"^(\d{4})/(\d{1,2})/(\d{1,2})$")
_SERIAL = re.compile(r"^\d{4,6}(\.\d+)?$")  # a spreadsheet date serial (days since 1899-12-30)


@dataclass
class Draft:
    """One task to create. `row` is the source row (spreadsheet line or Trello card index) for messages."""

    row: int
    title: str
    description: str = ""
    due_at: datetime | None = None
    all_day: bool = False
    column: str | None = None
    owner_refs: list[str] = field(default_factory=list)  # emails or usernames
    priority: str = "normal"
    checklist: list[tuple[str, bool]] = field(default_factory=list)
    labels: list[str] = field(default_factory=list)
    closed: bool = False


@dataclass
class Parsed:
    drafts: list[Draft] = field(default_factory=list)
    errors: list[dict] = field(default_factory=list)  # {"row", "message"}: rows that are skipped
    warnings: list[dict] = field(default_factory=list)  # {"row", "message"}: imported with something dropped
    skipped: int = 0
    columns: list[str] = field(default_factory=list)  # column titles in board order (Trello lists)

    def error(self, row: int, message: str) -> None:
        self.errors.append({"row": row, "message": message})
        self.skipped += 1

    def warn(self, row: int, message: str) -> None:
        self.warnings.append({"row": row, "message": message})


def clean_text(value: object) -> str:
    """Multi-line text: control characters removed, line breaks normalised."""
    return _CONTROL.sub("", str(value or "").replace("\r\n", "\n").replace("\r", "\n")).strip()


def clean_line(value: object, limit: int) -> str:
    """Single-line text: whitespace and control characters collapse to single spaces, cut at `limit`."""
    return " ".join(_CONTROL.sub(" ", str(value or "")).split())[:limit]


def _at_noon(day: date) -> datetime:
    return datetime.combine(day, time(12, 0), tzinfo=TEHRAN)


def parse_due(raw: str) -> tuple[datetime | None, bool]:
    """(moment, all_day) from ISO date/datetime, Jalali yyyy/mm/dd or a spreadsheet serial; ValueError otherwise."""
    text = str(raw or "").strip().translate(_DIGITS)
    if not text:
        return None, False
    match = _JALALI.match(text)
    if match:
        year, month, day = (int(g) for g in match.groups())
        if year < 1700:
            if not (1 <= month <= 12 and 1 <= day <= jalali.month_length(year, month)):
                raise ValueError("invalid Jalali date")
            return _at_noon(jalali.to_gregorian(year, month, day)), True
        return _at_noon(date(year, month, day)), True
    if _SERIAL.match(text):
        return _at_noon(date(1899, 12, 30) + timedelta(days=int(float(text)))), True
    if len(text) == 10:
        return _at_noon(date.fromisoformat(text)), True
    moment = datetime.fromisoformat(text)
    return (moment if moment.tzinfo else moment.replace(tzinfo=TEHRAN)), False


def parse_priority(raw: str) -> str:
    value = clean_line(raw, 20).lower() or "normal"
    if value not in PRIORITIES:
        raise ValueError("priority must be low, normal, high or urgent")
    return value


def too_many_rows(count: int) -> HttpError:
    return HttpError(422, f"At most {MAX_ROWS} rows can be imported at once (found {count})")
