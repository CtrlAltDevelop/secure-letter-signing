"""Bulk import of customers from CSV or xlsx. Columns: kind,name,legal_name,national_id,phone,mobile,email,address,status.

Rows with an existing (or repeated) national id or email are skipped; bad rows are reported, the rest is created.
"""
import csv
import io
import re
from dataclasses import dataclass, field

from django.db import transaction
from ninja.errors import HttpError

from accounts.models import User, audit
from core import xlsx

from . import notices, service
from .models import Customer
from .schemas import ImportError_, ImportOut

MAX_BYTES = 5 * 1024 * 1024
MAX_ROWS = 5000
COLUMNS = ("kind", "name", "legal_name", "national_id", "phone", "mobile", "email", "address", "status")
LIMITS = {"legal_name": 200, "national_id": 20, "phone": 30, "mobile": 30, "email": 254, "address": 20_000}
EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


@dataclass
class Report:
    created: int = 0
    skipped: int = 0
    errors: list[ImportError_] = field(default_factory=list)

    def out(self) -> ImportOut:
        return ImportOut(created=self.created, skipped=self.skipped, errors=self.errors)


def read_rows(raw: bytes, fmt: str) -> list[list[str]]:
    if len(raw) > MAX_BYTES:
        raise HttpError(413, "The file is larger than 5 MB")
    if fmt == "xlsx":
        try:
            return xlsx.read_first_sheet(raw)
        except xlsx.XlsxError as exc:
            raise HttpError(422, f"Unreadable xlsx file: {exc}") from exc
    try:
        text = raw.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise HttpError(422, "The CSV file must be UTF-8") from exc
    return [[c.strip() for c in row] for row in csv.reader(io.StringIO(text))]


def _records(rows: list[list[str]]) -> list[tuple[int, dict[str, str]]]:
    """[(sheet row number, {column: value})] for the data rows; 422 when the header or size is wrong."""
    if not rows:
        raise HttpError(422, "The file is empty")
    header = [h.strip().lower() for h in rows[0]]
    if "name" not in header:
        raise HttpError(422, "The header needs a name column")
    if len(rows) - 1 > MAX_ROWS:
        raise HttpError(422, f"At most {MAX_ROWS} rows can be imported at once")
    out = []
    for number, row in enumerate(rows[1:], start=2):
        record = {col: (row[i].strip() if i < len(row) else "") for i, col in enumerate(header) if col in COLUMNS}
        if any(record.values()):
            out.append((number, record))
    return out


def _problem(record: dict[str, str]) -> str | None:
    if not record.get("name"):
        return "name is required"
    if len(record["name"]) > 200:
        return "name is too long"
    if record.get("kind", "") not in ("", "person", "company"):
        return "kind must be person or company"
    if record.get("status", "") not in ("", "active", "inactive", "archived"):
        return "status must be active, inactive or archived"
    if record.get("email") and not EMAIL.match(record["email"]):
        return "email is not valid"
    for name, limit in LIMITS.items():
        if len(record.get(name, "")) > limit:
            return f"{name} is too long"
    return None


def _known_keys() -> tuple[set[str], set[str]]:
    rows = Customer.objects.values_list("national_id", "email")
    return ({n for n, _ in rows if n}, {e.lower() for _, e in rows if e})


def import_rows(user: User, rows: list[list[str]]) -> ImportOut:
    records = _records(rows)
    report, (known_ids, known_emails) = Report(), _known_keys()
    room = service.room_left()
    for number, record in records:
        problem = _problem(record)
        national, email = record.get("national_id", ""), record.get("email", "").lower()
        if problem:
            report.errors.append(ImportError_(row=number, message=problem))
        elif (national and national in known_ids) or (email and email in known_emails):
            report.skipped += 1
        elif room <= 0:
            report.errors.append(ImportError_(row=number, message=service.LIMIT_MESSAGE))
        else:
            _create(user, record)
            room -= 1
            report.created += 1
            known_ids.add(national)
            known_emails.add(email)
    audit(user, "customers_imported", "", created=report.created, skipped=report.skipped,
          errors=len(report.errors))
    return report.out()


@transaction.atomic
def _create(user: User, record: dict[str, str]) -> Customer:
    values = {
        "kind": record.get("kind") or Customer.PERSON, "name": record["name"],
        "legal_name": record.get("legal_name", ""), "national_id": record.get("national_id", ""),
        "phone": record.get("phone", ""), "mobile": record.get("mobile", ""),
        "email": record.get("email", "").lower(), "status": record.get("status") or Customer.ACTIVE}
    customer = service.new_customer(user, values, address=record.get("address", ""))
    notices.emit_customer("customer.created", customer, user, imported=True)
    return customer
