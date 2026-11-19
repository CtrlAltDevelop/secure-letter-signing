"""Minimal .xlsx reader (zip + XML, no third-party package): the first worksheet as rows of strings.

Hardened for untrusted uploads: XML with a DOCTYPE/ENTITY is refused and the unpacked size is capped.
"""
import io
import re
import zipfile
from xml.etree import ElementTree

NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
      "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
      "p": "http://schemas.openxmlformats.org/package/2006/relationships"}
MAX_PART_BYTES = 50 * 1024 * 1024
MAX_COLUMNS = 200
CELL_REF = re.compile(r"^([A-Z]+)(\d+)$")


class XlsxError(ValueError):
    """The file is not a readable workbook."""


def _part(zf: zipfile.ZipFile, name: str, *, required: bool = True) -> ElementTree.Element | None:
    try:
        info = zf.getinfo(name)
    except KeyError:
        if required:
            raise XlsxError(f"Missing part {name}") from None
        return None
    if info.file_size > MAX_PART_BYTES:
        raise XlsxError("The workbook is too large")
    raw = zf.read(info)
    if b"<!DOCTYPE" in raw or b"<!ENTITY" in raw:
        raise XlsxError("Unsupported XML")
    try:
        return ElementTree.fromstring(raw)
    except ElementTree.ParseError as exc:
        raise XlsxError("Broken XML") from exc


def _shared_strings(zf: zipfile.ZipFile) -> list[str]:
    root = _part(zf, "xl/sharedStrings.xml", required=False)
    if root is None:
        return []
    return ["".join(t.text or "" for t in si.iter(f"{{{NS['m']}}}t")) for si in root.findall("m:si", NS)]


def _first_sheet_path(zf: zipfile.ZipFile) -> str:
    book, rels = _part(zf, "xl/workbook.xml"), _part(zf, "xl/_rels/workbook.xml.rels")
    sheet = book.find("m:sheets/m:sheet", NS)
    if sheet is None:
        raise XlsxError("The workbook has no sheet")
    rid = sheet.get(f"{{{NS['r']}}}id")
    for rel in rels.findall("p:Relationship", NS):
        if rel.get("Id") == rid:
            target = rel.get("Target", "")
            return target.lstrip("/") if target.startswith("/") else f"xl/{target}"
    raise XlsxError("The first sheet is missing")


def _column_index(letters: str) -> int:
    n = 0
    for ch in letters:
        n = n * 26 + ord(ch) - 64
    return n - 1


def _number(text: str) -> str:
    try:
        value = float(text)
    except ValueError:
        return text
    return str(int(value)) if value.is_integer() and abs(value) < 1e15 else text


def _cell_text(cell: ElementTree.Element, strings: list[str]) -> str:
    kind = cell.get("t", "n")
    if kind == "inlineStr":
        return "".join(t.text or "" for t in cell.iter(f"{{{NS['m']}}}t"))
    value = cell.findtext("m:v", default="", namespaces=NS)
    if kind == "s":
        try:
            return strings[int(value)]
        except (ValueError, IndexError):
            return ""
    return _number(value) if kind == "n" else value


def _row_values(row: ElementTree.Element, strings: list[str]) -> list[str]:
    values: dict[int, str] = {}
    for position, cell in enumerate(row.findall("m:c", NS)):
        match = CELL_REF.match(cell.get("r", ""))
        index = _column_index(match.group(1)) if match else position
        if index >= MAX_COLUMNS:
            continue
        values[index] = _cell_text(cell, strings).strip()
    width = max(values, default=-1) + 1
    return [values.get(i, "") for i in range(width)]


def read_first_sheet(data: bytes) -> list[list[str]]:
    """Rows of the first worksheet as strings (empty cells are ""); raises XlsxError for anything unreadable."""
    try:
        zf = zipfile.ZipFile(io.BytesIO(data))
    except zipfile.BadZipFile as exc:
        raise XlsxError("Not an xlsx file") from exc
    with zf:
        strings = _shared_strings(zf)
        sheet = _part(zf, _first_sheet_path(zf))
        return [_row_values(row, strings) for row in sheet.findall("m:sheetData/m:row", NS)]
