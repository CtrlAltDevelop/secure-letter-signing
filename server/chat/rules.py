"""Who may do what in a conversation. Only active members see anything (the company manager gets nothing extra)."""
from typing import Any

from accounts.models import User

from .models import Conversation, ConversationMember

ADMIN = ConversationMember.ADMIN


def member_row(user: User, conv: Conversation) -> ConversationMember | None:
    return ConversationMember.objects.filter(conversation=conv, user=user, active=True).first()


def active_members(conv: Conversation):
    return ConversationMember.objects.filter(conversation=conv, active=True, user__is_active=True)


def member_ids(conv: Conversation) -> set[int]:
    return set(active_members(conv).values_list("user_id", flat=True))


def can_post_row(conv: Conversation, row: ConversationMember | None) -> bool:
    if row is None or conv.archived:
        return False
    return conv.post_policy == Conversation.ALL or row.role == ADMIN


def can(user: User, conv: Any, action: str) -> bool:
    row = member_row(user, conv)
    if row is None:
        return False
    if action == "see":
        return True
    if action == "comment":
        return can_post_row(conv, row)
    if action == "moderate":
        return row.role == ADMIN
    return False
