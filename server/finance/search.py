"""Unified search for `finance.manage` holders: customer name, amount, or description text.

Descriptions are encrypted, so they are decrypted one by one for the latest 500 visible documents only.
"""
import logging

from ninja.errors import HttpError

from accounts.models import User
from workspace.search import amount_of, hit
from workspace.textbox import open_text

from .rules import visible_docs

SCAN_CAP = 500
logger = logging.getLogger(__name__)


def _described(doc, needle: str) -> bool:
    try:
        return needle in open_text(doc.description).casefold()
    except HttpError:
        logger.error("Finance document %s cannot be decrypted during search", doc.id)
        return False


def search(user: User, q: str, limit: int) -> list[dict]:
    needle, amount, out = q.casefold(), amount_of(q), []
    rows = visible_docs(user).select_related("customer").order_by("-date", "-id")[:SCAN_CAP]
    for doc in rows:
        name = doc.customer.name if doc.customer_id else ""
        if needle in name.casefold() or (amount is not None and doc.amount == amount) or _described(doc, needle):
            out.append(hit("finance", "finance_doc", doc.id, doc.subject_id, f"{doc.direction} {doc.amount:,}", name,
                           doc.created_at))
            if len(out) >= limit:
                break
    return out
