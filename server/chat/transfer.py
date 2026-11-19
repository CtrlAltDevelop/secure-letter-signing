"""Work transfer: conversations a user administers (and the messages they pinned) go to a colleague.

Direct messages and project/customer chats stay as they are (they follow the people involved). The old user's
membership is deactivated; the new user keeps their own role unless they must become admin.
"""
from django.db import transaction

from accounts.models import User

from .mirror import is_mirrored
from .models import Conversation, ConversationMember, PinnedMessage

ADMIN, MEMBER = ConversationMember.ADMIN, ConversationMember.MEMBER


def _hand_over(source: ConversationMember, to_user: User) -> None:
    target = ConversationMember.objects.filter(conversation_id=source.conversation_id, user=to_user).first()
    if target is None:
        ConversationMember.objects.create(conversation_id=source.conversation_id, user=to_user, role=source.role)
    else:
        role = ADMIN if ADMIN in (source.role, target.role) else MEMBER
        ConversationMember.objects.filter(pk=target.pk).update(active=True, role=role)
    ConversationMember.objects.filter(pk=source.pk).update(active=False)


@transaction.atomic
def transfer(from_user: User, to_user: User, actor: User) -> dict[str, int]:
    rows = (ConversationMember.objects.select_for_update()
            .filter(user=from_user, active=True).exclude(conversation__kind=Conversation.DM)
            .select_related("conversation"))
    moved = 0
    for row in rows:
        if is_mirrored(row.conversation):
            continue
        _hand_over(row, to_user)
        Conversation.objects.filter(pk=row.conversation_id, creator=from_user).update(creator=to_user)
        moved += 1
    pins = PinnedMessage.objects.filter(pinned_by=from_user).update(pinned_by=to_user)
    return {"chat": moved, "chat_pins": pins}
