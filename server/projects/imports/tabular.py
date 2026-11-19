"""CSV and XLSX imports: header row `title, description, due, column, owner_email, priority, checklist`.

`due` is an ISO date/datetime or a Jalali yyyy/mm/dd; `checklist` items are separated by `|`. Header names are matched
case-insensitively, unknown columns are ignored. Cell text is data only: nothing is evaluated.
"""
import csv
import io

from ninja.errors import HttpError

from . import xlsx
from .model import (MAX_CHECKLIST, MAX_DESCRIPTION, MAX_ITEM, MAX_ROWS, MAX_TITLE, Draft, Parsed, clean_line,
                    clean_text, parse_due, parse_priority, too_many_rows)

HEADERS = ("title", "description", "due", "column", "owner_email", "priority", "checklist")


def _csv_rows(data: bytes) -> list[tuple[int, list[str]]]:
    try:
        text = data.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise HttpError(422, "The CSV file must be UTF-8 text") from exc
    rows = []
    try:
        for number, cells in enumerate(csv.reader(io.StringIO(text)), start=1):
            if any(c.strip() for c in cells):
                rows.append((number, cells))
                if len(rows) > MAX_ROWS + 1:
                    raise too_many_rows(len(rows) - 1)
    except csv.Error as exc:
        raise HttpError(422, "The CSV file is malformed") from exc
    return rows


def _header_map(header: list[str]) -> dict[str, int]:
    names = {clean_line(h, 60).lower(): i for i, h in reversed(list(enumerate(header)))}
    if "title" not in names:
        raise HttpError(422, "The first row must be a header containing a 'title' column")
    return {h: names[h] for h in HEADERS if h in names}


def _draft(number: int, cells: list[str], columns: dict[str, int], out: Parsed) -> Draft | None:
    def get(name: str) -> str:
        index = columns.get(name)
        return cells[index] if index is not None and index < len(cells) else ""

    title = clean_line(get("title"), MAX_TITLE)
    if not title:
        out.error(number, "title is required")
        return None
    try:
        priority = parse_priority(get("priority"))
        due, all_day = parse_due(get("due"))
    except ValueError as exc:
        message = str(exc) if "priority" in str(exc) else "due is not a valid ISO or Jalali (yyyy/mm/dd) date"
        out.error(number, message)
        return None
    items = [clean_line(i, MAX_ITEM) for i in get("checklist").split("|")]
    owner = clean_line(get("owner_email"), 150)
    return Draft(row=number, title=title, description=clean_text(get("description"))[:MAX_DESCRIPTION], due_at=due,
                 all_day=all_day, column=clean_line(get("column"), 100) or None, owner_refs=[owner] if owner else [],
                 priority=priority, checklist=[(i, False) for i in items if i][:MAX_CHECKLIST])


def parse(data: bytes, fmt: str) -> Parsed:
    rows = _csv_rows(data) if fmt == "csv" else xlsx.read_rows(data, MAX_ROWS)
    out = Parsed()
    if not rows:
        raise HttpError(422, "The file is empty")
    columns = _header_map(rows[0][1])
    for number, cells in rows[1:]:
        draft = _draft(number, cells, columns, out)
        if draft:
            out.drafts.append(draft)
    return out
