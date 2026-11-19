"""Hooks for the workspace-wide features: unified search (conversation names, message text) and message bookmarks.

Message text is encrypted, so search decrypts only the latest MESSAGE_SCAN_CAP messages across the caller's conversations.
"""
import logging

from accounts.models import User
from workspace.search import hit

from . import bodies
from .models import Conversation, ConversationMember, Message

MESSAGE_SCAN_CAP = 1000
SNIPPET = 80
logger = logging.getLogger(__name__)


def _mine(user: User):
    return ConversationMember.objects.filter(user=user, active=True).values("conversation_id")


def _snippet(text: str, needle: str) -> str:
    at = max(text.casefold().find(needle), 0)
    start = max(at - SNIPPET // 4, 0)
    return text[start: start + SNIPPET]


def search(user: User, q: str, limit: int) -> list[dict]:
    needle = q.casefold()
    convs = Conversation.objects.filter(pk__in=_mine(user), name__icontains=q).order_by("-last_message_at", "id")
    out = [hit("chat", "conversation", c.id, c.subject_id, c.name, "", c.last_message_at or c.created_at)
           for c in convs[:limit]]
    rows = (Message.objects.filter(conversation_id__in=_mine(user), deleted=False).exclude(kind=Message.SYSTEM)
            .select_related("conversation").order_by("-created_at", "-id")[:MESSAGE_SCAN_CAP])
    for msg in rows:
        if len(out) >= limit:
            break
        text = str(bodies.open_body(msg.body).get("text", ""))
        if needle in text.casefold():
            conv = msg.conversation
            out.append(hit("chat", "message", msg.id, conv.subject_id, conv.name, _snippet(text, needle),
                           msg.created_at))
    return out[:limit]


def bookmark_check(user: User, target_id: str) -> str | None:
    """Title (the conversation name, never message text) when `target_id` is a live message in a conversation the
    user is an active member of, else None."""
    if not target_id.isdigit():
        return None
    msg = (Message.objects.filter(pk=int(target_id), deleted=False, conversation_id__in=_mine(user))
           .select_related("conversation").first())
    return None if msg is None else msg.conversation.name
