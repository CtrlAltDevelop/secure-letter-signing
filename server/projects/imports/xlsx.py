"""A minimal .xlsx reader (openpyxl is not installed): the first sheet as rows of strings.

Reads shared strings, inline strings and the cached value of every cell. Formulas are never evaluated (only the value
the file already stores is used), macros are never touched, and XML with a DOCTYPE/ENTITY is refused outright.
"""
import io
import posixpath
import re
import zipfile
from xml.etree import ElementTree

from ninja.errors import HttpError

MAX_UNPACKED = 50 * 1024 * 1024  # all XML parts together (zip bomb guard)
_REF = re.compile(r"^([A-Z]+)")
_REL = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"


def _local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def _xml(zf: zipfile.ZipFile, name: str) -> ElementTree.Element:
    raw = zf.read(name)
    if b"<!DOCTYPE" in raw[:2000].upper() or b"<!ENTITY" in raw.upper():
        raise HttpError(422, "The spreadsheet contains unsupported XML")
    try:
        return ElementTree.fromstring(raw)
    except ElementTree.ParseError as exc:
        raise HttpError(422, "The spreadsheet is damaged") from exc


def _text(node: ElementTree.Element) -> str:
    """Text of an <si> or <is>: its <t> children and rich-text runs, without phonetic hints."""
    parts = []
    for child in node:
        if _local(child.tag) == "t":
            parts.append(child.text or "")
        elif _local(child.tag) == "r":
            parts.extend(t.text or "" for t in child if _local(t.tag) == "t")
    return "".join(parts)


def _shared_strings(zf: zipfile.ZipFile) -> list[str]:
    if "xl/sharedStrings.xml" not in zf.namelist():
        return []
    return [_text(si) for si in _xml(zf, "xl/sharedStrings.xml") if _local(si.tag) == "si"]


def _first_sheet_path(zf: zipfile.ZipFile) -> str:
    names = zf.namelist()
    if "xl/workbook.xml" in names and "xl/_rels/workbook.xml.rels" in names:
        sheets = [e for e in _xml(zf, "xl/workbook.xml").iter() if _local(e.tag) == "sheet"]
        rels = {r.get("Id"): r.get("Target") for r in _xml(zf, "xl/_rels/workbook.xml.rels")}
        target = rels.get(sheets[0].get(_REL)) if sheets else None
        if target:
            path = target.lstrip("/") if target.startswith("/") else posixpath.normpath(posixpath.join("xl", target))
            if path in names:
                return path
    found = sorted(n for n in names if re.fullmatch(r"xl/worksheets/sheet\d+\.xml", n))
    if not found:
        raise HttpError(422, "The spreadsheet has no worksheet")
    return found[0]


def _column_index(ref: str, fallback: int) -> int:
    match = _REF.match(ref or "")
    if not match:
        return fallback
    index = 0
    for ch in match.group(1):
        index = index * 26 + ord(ch) - 64
    return index - 1


def _cell_value(cell: ElementTree.Element, shared: list[str]) -> str:
    kind = cell.get("t")
    if kind == "inlineStr":
        return "".join(_text(n) for n in cell if _local(n.tag) == "is")
    value = next((c.text or "" for c in cell if _local(c.tag) == "v"), "")
    if kind == "s":
        return shared[int(value)] if value.isdigit() and int(value) < len(shared) else ""
    if kind == "b":
        return "TRUE" if value == "1" else "FALSE"
    return value


def read_rows(data: bytes, max_rows: int) -> list[tuple[int, list[str]]]:
    """[(spreadsheet row number, cell strings)] of the first sheet; HttpError 422 above `max_rows` rows."""
    try:
        zf = zipfile.ZipFile(io.BytesIO(data))
    except zipfile.BadZipFile as exc:
        raise HttpError(422, "The file is not an .xlsx spreadsheet") from exc
    with zf:
        if sum(i.file_size for i in zf.infolist()) > MAX_UNPACKED:
            raise HttpError(422, "The spreadsheet is too large when unpacked")
        shared = _shared_strings(zf)
        sheet = _xml(zf, _first_sheet_path(zf))
    rows = []
    for number, row in enumerate((e for e in sheet.iter() if _local(e.tag) == "row"), start=1):
        cells: list[str] = []
        for position, cell in enumerate(c for c in row if _local(c.tag) == "c"):
            index = _column_index(cell.get("r", ""), position)
            cells.extend([""] * (index + 1 - len(cells)))
            cells[index] = _cell_value(cell, shared)
        if any(v.strip() for v in cells):
            rows.append((int(row.get("r") or number), cells))
            if len(rows) > max_rows + 1:
                raise HttpError(422, f"At most {max_rows} rows can be imported at once")
    return rows
