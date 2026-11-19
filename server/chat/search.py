"""Search over message text. Bodies are encrypted, so this decrypts and scans only the SCAN_CAP most recent messages
across the caller's conversations (newest first); older messages are not found."""
from uuid import UUID

from accounts.models import User

from . import bodies
from .models import ConversationMember, Message

SCAN_CAP = 2000
MAX_LIMIT = 100


def search(user: User, query: str, conversation_id: UUID | None, limit: int) -> list[Message]:
    needle = query.strip().casefold()
    if not needle:
        return []
    mine = ConversationMember.objects.filter(user=user, active=True)
    if conversation_id is not None:
        mine = mine.filter(conversation_id=conversation_id)
    rows = (Message.objects.filter(conversation_id__in=mine.values("conversation_id"), deleted=False)
            .exclude(kind=Message.SYSTEM).select_related("author", "author__org_title", "file")
            .order_by("-created_at", "-id")[:SCAN_CAP])
    hits: list[Message] = []
    for msg in rows:
        if needle in bodies.open_text(msg.body).casefold():
            hits.append(msg)
            if len(hits) >= max(min(limit, MAX_LIMIT), 0):
                break
    return hits
