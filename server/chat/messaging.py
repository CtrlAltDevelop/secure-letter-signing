"""Messages: post, edit, delete (tombstone), read receipts, pins. Text is encrypted at rest; audit rows carry ids only."""
from datetime import datetime
from zoneinfo import ZoneInfo

from django.db import transaction
from django.utils import timezone
from ninja.errors import HttpError

from accounts import ratelimit
from accounts.models import User, audit
from accounts.notify import notify
from workspace.models import File

from . import bodies, events, rules
from .models import Conversation, ConversationMember, Message, MessageRead, PinnedMessage
from .schemas import MessageIn

RATE_MAX, RATE_WINDOW = 30, 60  # messages per user per minute
RECEIPT_CAP = 200  # per-message receipts only for conversations with at most this many members
RECEIPT_BACKLOG = 1000  # at most this many latest messages get receipts in one read call
PIN_CAP = 50
AUDIO_PREFIX = "audio/"
FILE_KIND_TYPES = ("image/", "application/pdf", AUDIO_PREFIX)


def _file_of(conv: Conversation, data: MessageIn) -> File | None:
    if data.file_id is None:
        return None
    file = File.objects.filter(pk=data.file_id, subject_id=conv.subject_id, active=True).first()
    if file is None:
        raise HttpError(422, "Unknown file; upload it to the conversation first")
    return file


def _kind(data: MessageIn, file: File | None, conv: Conversation) -> str:
    kind = data.kind or (Message.FILE if file else Message.TEXT)
    if kind == Message.TEXT and file:
        kind = Message.FILE
    if kind in (Message.FILE, Message.VOICE) and file is None:
        raise HttpError(422, "A file message needs file_id")
    if kind == Message.TEXT and not data.text.strip():
        raise HttpError(422, "Message is empty")
    if kind == Message.FILE and not file.content_type.startswith(FILE_KIND_TYPES):
        raise HttpError(422, "Unsupported file type")
    if kind == Message.VOICE:
        if conv.kind != Conversation.DM:
            raise HttpError(422, "Voice messages are only allowed in direct messages")
        if not file.content_type.startswith(AUDIO_PREFIX):
            raise HttpError(422, "A voice message needs an audio file")
    return kind


def _mentions(conv: Conversation, ids: list[int]) -> list[int]:
    unique = list(dict.fromkeys(ids))
    if unique and not set(unique) <= rules.member_ids(conv):
        raise HttpError(422, "Only members of the conversation can be mentioned")
    return unique


def _reply(conv: Conversation, reply_id: int | None) -> Message | None:
    if reply_id is None:
        return None
    row = Message.objects.filter(pk=reply_id, conversation=conv).first()
    if row is None:
        raise HttpError(422, "Unknown message to reply to")
    return row


def next_seq(conv: Conversation) -> tuple[Conversation, int]:
    """Lock the conversation row and take the next gap-free sequence number (rolls back with the caller)."""
    locked = Conversation.objects.select_for_update().get(pk=conv.pk)
    return locked, locked.last_seq + 1


def store(conv: Conversation, author: User, **fields) -> Message:
    locked, seq = next_seq(conv)
    msg = Message.objects.create(conversation=conv, seq=seq, author=author, **fields)
    Conversation.objects.filter(pk=conv.pk).update(last_seq=seq, last_message_at=msg.created_at)
    conv.last_seq, conv.last_message_at = seq, msg.created_at
    return msg


@transaction.atomic
def post_message(user: User, conv: Conversation, data: MessageIn) -> Message:
    row = rules.member_row(user, conv)
    if row is None:
        raise HttpError(404, "Not found")
    if conv.archived:
        raise HttpError(409, "This conversation is archived")
    if not rules.can_post_row(conv, row):
        raise HttpError(403, "Only admins may post here")
    ratelimit.hit("chat-message", str(user.id), RATE_MAX, RATE_WINDOW)
    file = _file_of(conv, data)
    kind = _kind(data, file, conv)
    mentions, reply = _mentions(conv, data.mentions), _reply(conv, data.reply_to_id)
    msg = store(conv, user, kind=kind, body=bodies.seal_body(data.text.strip()), reply_to=reply,
                 mentions=mentions, file=file)
    ConversationMember.objects.filter(pk=row.pk, last_read_seq=msg.seq - 1).update(last_read_seq=msg.seq)
    audit(user, "chat_message_sent", str(msg.id), conversation=str(conv.id), seq=msg.seq, kind=kind)
    events.message_created(conv, msg, data.text)
    _notify_mentions(conv, user, msg, mentions)
    return msg


def _notify_mentions(conv: Conversation, author: User, msg: Message, mentions: list[int]) -> None:
    users = User.objects.filter(pk__in=[m for m in mentions if m != author.id], is_active=True)
    notify(users, "chat.mention", author.full_name or author.email, module="chat", conversation_id=str(conv.id),
           subject_id=str(conv.subject_id), message_id=msg.id, seq=msg.seq)


def message_of(user: User, message_id: int) -> tuple[Message, Conversation]:
    """The message and its conversation; 404 unless the caller is an active member."""
    from . import service

    service.gate()
    msg = Message.objects.select_related("conversation__subject", "author", "file").filter(pk=message_id).first()
    if msg is None:
        raise HttpError(404, "Not found")
    return msg, service.load(user, msg.conversation_id)


@transaction.atomic
def edit_message(user: User, message_id: int, text: str) -> Message:
    msg, conv = message_of(user, message_id)
    if msg.author_id != user.id or msg.kind in (Message.SYSTEM, Message.VOICE):
        raise HttpError(403, "Permission denied")
    if msg.deleted:
        raise HttpError(409, "Message was deleted")
    if not text.strip() and not msg.file_id:
        raise HttpError(422, "Message is empty")
    msg.body, msg.edited_at = bodies.seal_body(text.strip()), timezone.now()
    msg.save(update_fields=["body", "edited_at"])
    audit(user, "chat_message_edited", str(msg.id), conversation=str(conv.id))
    events.message_changed("chat.message_edited", conv, msg, user)
    return msg


@transaction.atomic
def delete_message(user: User, message_id: int) -> None:
    msg, conv = message_of(user, message_id)
    row = rules.member_row(user, conv)
    if msg.author_id != user.id and row.role != rules.ADMIN:
        raise HttpError(403, "Permission denied")
    if msg.deleted:
        return
    msg.deleted, msg.body = True, {}
    msg.save(update_fields=["deleted", "body"])
    PinnedMessage.objects.filter(message=msg).update(active=False)
    audit(user, "chat_message_deleted", str(msg.id), conversation=str(conv.id))
    events.message_changed("chat.message_deleted", conv, msg, user)


@transaction.atomic
def mark_read(user: User, conv: Conversation, seq: int) -> int:
    """Advance the caller's read position (never backwards); returns the stored `last_read_seq`."""
    row = ConversationMember.objects.select_for_update().get(conversation=conv, user=user, active=True)
    target = min(seq, conv.last_seq)
    if target <= row.last_read_seq:
        return row.last_read_seq
    previous, row.last_read_seq = row.last_read_seq, target
    row.save(update_fields=["last_read_seq"])
    size = rules.active_members(conv).count()
    if size <= RECEIPT_CAP:
        _record_receipts(conv, user, previous, target)
    events.read(conv, user, target, to_all=size <= RECEIPT_CAP)
    return target


def _record_receipts(conv: Conversation, user: User, after: int, upto: int) -> None:
    ids = list(Message.objects.filter(conversation=conv, seq__gt=after, seq__lte=upto, deleted=False)
               .exclude(author=user).order_by("-seq").values_list("id", flat=True)[:RECEIPT_BACKLOG])
    MessageRead.objects.bulk_create([MessageRead(message_id=i, user=user) for i in ids], ignore_conflicts=True)


def seen_by(user: User, message_id: int) -> tuple[Message, bool, list[MessageRead]]:
    msg, conv = message_of(user, message_id)
    if msg.author_id != user.id and rules.member_row(user, conv).role != rules.ADMIN:
        raise HttpError(403, "Permission denied")
    tracked = rules.active_members(conv).count() <= RECEIPT_CAP
    reads = MessageRead.objects.filter(message=msg).select_related("user", "user__org_title").order_by("at", "id")
    return msg, tracked, list(reads)


@transaction.atomic
def set_pin(user: User, message_id: int, active: bool) -> tuple[Message, Conversation]:
    msg, conv = message_of(user, message_id)
    row = rules.member_row(user, conv)
    if conv.kind != Conversation.DM and row.role != rules.ADMIN:
        raise HttpError(403, "Permission denied")
    if msg.deleted or msg.kind == Message.SYSTEM:
        raise HttpError(409, "This message cannot be pinned")
    pin = PinnedMessage.objects.filter(message=msg).first()
    if pin is not None and pin.active == active:
        return msg, conv
    if active and PinnedMessage.objects.filter(conversation=conv, active=True).count() >= PIN_CAP:
        raise HttpError(422, f"At most {PIN_CAP} pinned messages")
    if pin is None:
        PinnedMessage.objects.create(conversation=conv, message=msg, pinned_by=user)
    else:
        pin.active, pin.pinned_by, pin.at = active, user, timezone.now()
        pin.save(update_fields=["active", "pinned_by", "at"])
    events.pinned(conv, msg, user, active)
    return msg, conv


def around_date_start(conv: Conversation, day) -> int | None:
    """Seq of the first message created on or after `day` (a date, Asia/Tehran midnight), None when there is none."""

    start = datetime(day.year, day.month, day.day, tzinfo=ZoneInfo("Asia/Tehran"))
    first = Message.objects.filter(conversation=conv, created_at__gte=start).order_by("seq").first()
    return first.seq if first else None


def window(conv: Conversation, *, before: int | None, after: int | None, around: int | None, limit: int) -> list[Message]:
    qs = Message.objects.filter(conversation=conv).select_related("author", "author__org_title", "file")
    if around is not None:
        rows = list(qs.filter(seq__gte=around).order_by("seq")[:limit])
    elif after is not None:
        rows = list(qs.filter(seq__gt=after).order_by("seq")[:limit])
    else:
        if before is not None:
            qs = qs.filter(seq__lt=before)
        rows = list(qs.order_by("-seq")[:limit])[::-1]
    return rows


