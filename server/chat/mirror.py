"""Project and customer chats: the conversation's members mirror the source's active members.

Managers of the source become admins. `sync` is idempotent; it runs from signals, when the chat is opened, and
whenever a conversation is resolved, so rows written by bulk paths that skip signals still converge.
"""
from uuid import UUID

from accounts.models import User

from . import events
from .models import Conversation, ConversationMember

ADMIN, MEMBER = ConversationMember.ADMIN, ConversationMember.MEMBER


def is_mirrored(conv: Conversation) -> bool:
    return bool(conv.project_id or conv.customer_ref)


def desired(conv: Conversation) -> dict[int, str]:
    """user id -> chat role for the active members of the source."""
    if conv.project_id:
        from projects.models import ProjectMember as Row

        rows = Row.objects.filter(project_id=conv.project_id, active=True, user__is_active=True)
    else:
        from crm.models import CustomerMember as Row

        rows = Row.objects.filter(customer_id=conv.customer_ref, active=True, user__is_active=True)
    return {uid: ADMIN if role == "manager" else MEMBER for uid, role in rows.values_list("user_id", "role")}


def _apply(conv: Conversation, wanted: dict[int, str]) -> list[int]:
    rows = {m.user_id: m for m in ConversationMember.objects.filter(conversation=conv)}
    added: list[int] = []
    for uid, role in wanted.items():
        row = rows.get(uid)
        if row is None:
            ConversationMember.objects.create(conversation=conv, user_id=uid, role=role)
            added.append(uid)
        elif not row.active or row.role != role:
            if not row.active:
                added.append(uid)
            row.active, row.role = True, role
            row.save(update_fields=["active", "role"])
    for uid, row in rows.items():
        if uid not in wanted and row.active:
            row.active = False
            row.save(update_fields=["active"])
    return added


def sync(conv: Conversation, *, announce: bool = True) -> list[int]:
    """Make the active members equal the source's; returns the user ids that were added."""
    added = _apply(conv, desired(conv))
    if added and announce:
        events.member_added(conv, added)
    return added


def chat_of_source(*, project_id=None, customer_ref: UUID | None = None) -> Conversation | None:
    if project_id:
        return Conversation.objects.filter(project_id=project_id).first()
    return Conversation.objects.filter(customer_ref=customer_ref).first()


def ensure_chat(user: User, *, project=None, customer=None) -> Conversation:
    """The source's group conversation, created on the first call; members are synced either way."""
    from workspace.models import Subject

    conv = chat_of_source(project_id=project.pk if project else None,
                          customer_ref=customer.pk if customer else None)
    if conv is None:
        subject = Subject.objects.create(module="chat", kind="conversation")
        name = project.name if project else customer.name
        owner = project.owner if project else customer.owner
        conv = Conversation.objects.create(
            subject=subject, kind=Conversation.GROUP, name=name[:100], creator=owner or user,
            project=project, customer_ref=customer.pk if customer else None)
        sync(conv, announce=False)
    else:
        sync(conv)
    return conv

