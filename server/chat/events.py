"""Live events of the chat module (workspace stream, module `chat`).

Kinds: chat.message|message_edited|message_deleted|read|pinned|member_added. Frames stay small: ids plus, for
`chat.message`, a decrypted `preview` (<= 80 chars) that is pushed live to non-muted members only and is never
written to the event table (replay carries ids only; the app fetches the message).
"""
from django.db import transaction

from accounts.models import User
from accounts.notify import push
from workspace.events import frame
from workspace.models import Event, EventRecipient

from .models import Conversation, ConversationMember, Message
from .rules import active_members

MODULE = "chat"
PREVIEW_CHARS = 80


def preview_of(text: str) -> str:
    flat = " ".join(text.split())
    return flat if len(flat) <= PREVIEW_CHARS else flat[: PREVIEW_CHARS - 1] + "…"


def _write(conv: Conversation, kind: str, actor: User | None, recipients: list[ConversationMember],
           preview: str | None = None, **data) -> Event:
    """Store the event (without preview) and push it on commit; muted members get no preview."""
    ids = [m.user_id for m in recipients]
    ev = Event.objects.create(module=MODULE, kind=kind, subject=conv.subject, title="", actor=actor,
                              data={"conversation_id": str(conv.id), **data})
    EventRecipient.objects.bulk_create([EventRecipient(event=ev, user_id=uid) for uid in ids])
    plain, loud = frame(ev), frame(ev)
    if preview is not None:
        loud["data"] = {**loud["data"], "preview": preview}
    muted = {m.user_id for m in recipients if m.muted}

    def deliver() -> None:
        for uid in ids:
            push(uid, plain if uid in muted else loud)

    transaction.on_commit(deliver)
    return ev


def _everyone(conv: Conversation) -> list[ConversationMember]:
    return list(active_members(conv))


def message_created(conv: Conversation, msg: Message, text: str) -> None:
    _write(conv, "chat.message", msg.author, _everyone(conv), preview_of(text), seq=msg.seq,
           author_id=msg.author_id, message_id=msg.id, msg_kind=msg.kind)


def message_changed(kind: str, conv: Conversation, msg: Message, actor: User) -> None:
    _write(conv, kind, actor, _everyone(conv), seq=msg.seq, author_id=msg.author_id, message_id=msg.id)


def read(conv: Conversation, user: User, seq: int, to_all: bool) -> None:
    rows = _everyone(conv) if to_all else [m for m in _everyone(conv) if m.user_id == user.id]
    _write(conv, "chat.read", user, rows, seq=seq, user_id=user.id)


def pinned(conv: Conversation, msg: Message, actor: User, active: bool) -> None:
    _write(conv, "chat.pinned", actor, _everyone(conv), seq=msg.seq, message_id=msg.id, pinned=active)


def member_added(conv: Conversation, user_ids: list[int], actor: User | None = None) -> None:
    _write(conv, "chat.member_added", actor, _everyone(conv), user_ids=sorted(user_ids))
