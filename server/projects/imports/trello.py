"""Trello board JSON export -> drafts: lists become columns, cards tasks, checklists checklist items, labels labels.

Only data is read; nothing in the file is executed or fetched. Archived lists are skipped with their cards, archived
cards (`closed`) are imported as cancelled tasks.
"""
import json
from collections import defaultdict

from ninja.errors import HttpError

from .model import (MAX_CHECKLIST, MAX_DESCRIPTION, MAX_ITEM, MAX_LABEL, MAX_ROWS, MAX_TITLE, Draft, Parsed,
                    clean_line, clean_text, parse_due, too_many_rows)


def _load(data: bytes) -> dict:
    try:
        board = json.loads(data.decode("utf-8-sig"))
    except (UnicodeDecodeError, ValueError) as exc:
        raise HttpError(422, "The file is not valid JSON") from exc
    if not isinstance(board, dict) or not isinstance(board.get("cards"), list) \
            or not isinstance(board.get("lists", []), list):
        raise HttpError(422, "This does not look like a Trello board export (cards and lists are missing)")
    if len(board["cards"]) > MAX_ROWS:
        raise too_many_rows(len(board["cards"]))
    return board


def _sorted(rows: list) -> list[dict]:
    items = [r for r in rows if isinstance(r, dict)]
    return sorted(items, key=lambda r: r.get("pos") if isinstance(r.get("pos"), (int, float)) else 0)


def _checklists(board: dict) -> dict[str, list[tuple[str, bool]]]:
    by_card: dict[str, list[tuple[str, bool]]] = defaultdict(list)
    for checklist in _sorted(board.get("checklists") or []):
        for item in _sorted(checklist.get("checkItems") or []):
            text = clean_line(item.get("name"), MAX_ITEM)
            if text:
                by_card[checklist.get("idCard")].append((text, item.get("state") == "complete"))
    return by_card


def _label_names(board: dict) -> dict[str, str]:
    names = {}
    for label in board.get("labels") or []:
        if isinstance(label, dict):
            name = clean_line(label.get("name") or label.get("color"), MAX_LABEL)
            if name:
                names[label.get("id")] = name
    return names


def _member_refs(board: dict) -> dict[str, str]:
    refs = {}
    for member in board.get("members") or []:
        if isinstance(member, dict):
            ref = clean_line(member.get("email") or member.get("username"), 150)
            if ref:
                refs[member.get("id")] = ref
    return refs


def _due(card: dict, number: int, out: Parsed) -> tuple:
    try:
        return parse_due(card.get("due") or "")
    except ValueError:
        out.warn(number, "The due date was not understood and was dropped")
        return None, False


def parse(data: bytes) -> Parsed:
    board = _load(data)
    out = Parsed()
    lists = {lst.get("id"): lst for lst in _sorted(board.get("lists") or [])}
    out.columns = [clean_line(lst.get("name"), 100) for lst in lists.values() if not lst.get("closed")]
    checks, labels, members = _checklists(board), _label_names(board), _member_refs(board)
    order = {list_id: i for i, list_id in enumerate(lists)}
    indexed = sorted(enumerate(board["cards"], start=1), key=lambda p: (
        order.get(p[1].get("idList"), len(order)) if isinstance(p[1], dict) else 0, p[0]))
    for number, card in indexed:
        if not isinstance(card, dict):
            out.error(number, "Not a card")
            continue
        lst = lists.get(card.get("idList"))
        title = clean_line(card.get("name"), MAX_TITLE)
        if lst is None or lst.get("closed"):
            out.error(number, "The card's list is archived or unknown")
        elif not title:
            out.error(number, "The card has no name")
        else:
            due, all_day = _due(card, number, out)
            out.drafts.append(Draft(
                row=number, title=title, description=clean_text(card.get("desc"))[:MAX_DESCRIPTION], due_at=due,
                all_day=all_day, column=clean_line(lst.get("name"), 100) or None,
                owner_refs=[members[m] for m in card.get("idMembers") or [] if m in members],
                checklist=checks.get(card.get("id"), [])[:MAX_CHECKLIST],
                labels=[labels[i] for i in card.get("idLabels") or [] if i in labels], closed=bool(card.get("closed"))))
    return out
