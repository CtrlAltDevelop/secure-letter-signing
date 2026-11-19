"""Models -> API shapes, loading related rows in a fixed number of queries."""
from collections.abc import Sequence

from django.db.models import Count, Q

from accounts.models import User
from workspace.models import File
from workspace.schemas import user_ref

from . import bodies, rules
from .events import preview_of
from .mirror import is_mirrored
from .models import Conversation, ConversationMember, Message, PinnedMessage
from .schemas import CanOut, ConversationOut, FileRef, MemberOut, MessageOut, ReplyRef
from .unread import counts_for

BODY_KEYS = ("text", "v", "ct")


def _system_data(kind: str, body: dict) -> dict | None:
    if kind != Message.SYSTEM:
        return None
    return {k: v for k, v in body.items() if k not in BODY_KEYS} or None


def message_outs(messages: Sequence[Message]) -> list[MessageOut]:
    ids = [m.id for m in messages]
    pinned = set(PinnedMessage.objects.filter(message_id__in=ids, active=True).values_list("message_id", flat=True))
    reply_ids = {m.reply_to_id for m in messages if m.reply_to_id}
    reply_rows = {r.id: r for r in Message.objects.filter(id__in=reply_ids)}
    out: list[MessageOut] = []
    for m in messages:
        body = {} if m.deleted else bodies.open_body(m.body)
        file = m.file if (m.file_id and not m.deleted) else None
        out.append(MessageOut(
            id=m.id, conversation_id=m.conversation_id, seq=m.seq, author=user_ref(m.author), kind=m.kind,
            text=str(body.get("text", "")), reply_to=_reply_ref(reply_rows.get(m.reply_to_id)),
            mentions=[] if m.deleted else list(m.mentions),
            file=FileRef(id=file.id, name=file.name, content_type=file.content_type, size=file.size) if file else None,
            data=_system_data(m.kind, body), created_at=m.created_at, edited_at=m.edited_at,
            edited=m.edited_at is not None, deleted=m.deleted, pinned=m.id in pinned))
    return out


def _reply_ref(row: Message | None) -> ReplyRef | None:
    if row is None:
        return None
    text = "" if row.deleted else preview_of(bodies.open_text(row.body))
    return ReplyRef(id=row.id, seq=row.seq, author_id=row.author_id, preview=text)


def _previews(convs: Sequence[Conversation]) -> dict:
    q = Q()
    for c in convs:
        if c.last_seq:
            q |= Q(conversation_id=c.id, seq=c.last_seq)
    if not q:
        return {}
    rows = Message.objects.filter(q, deleted=False)
    return {m.conversation_id: preview_of(bodies.open_text(m.body)) for m in rows}


def _can(conv: Conversation, row: ConversationMember | None) -> CanOut:
    joinable = (row is None and conv.is_public and conv.kind != Conversation.DM and not conv.archived
                and not is_mirrored(conv))
    return CanOut(post=rules.can_post_row(conv, row), admin=bool(row and row.role == rules.ADMIN), join=joinable)


def _others(user: User, dms: Sequence[Conversation]) -> dict:
    rows = (ConversationMember.objects.filter(conversation__in=dms).exclude(user=user)
            .select_related("user", "user__org_title"))
    return {r.conversation_id: r.user for r in rows}


def _members(conv: Conversation) -> list[MemberOut]:
    rows = rules.active_members(conv).select_related("user", "user__org_title").order_by("joined_at", "id")
    return [MemberOut(user=user_ref(r.user), role=r.role, muted=r.muted) for r in rows]


def conversation_outs(user: User, convs: Sequence[Conversation], *, detail: bool = False) -> list[ConversationOut]:
    ids = [c.id for c in convs]
    rows = {r.conversation_id: r for r in ConversationMember.objects.filter(
        user=user, active=True, conversation_id__in=ids)}
    sizes = dict(ConversationMember.objects.filter(conversation_id__in=ids, active=True, user__is_active=True)
                 .values("conversation_id").annotate(n=Count("id")).values_list("conversation_id", "n"))
    counts = counts_for(user, ids)
    previews = _previews(convs)
    others = _others(user, [c for c in convs if c.kind == Conversation.DM])
    out: list[ConversationOut] = []
    for c in convs:
        row, cnt, other = rows.get(c.id), counts.get(c.id), others.get(c.id)
        out.append(ConversationOut(
            id=c.id, subject_id=c.subject_id, kind=c.kind, name=other.full_name if other else c.name,
            description=c.description, is_public=c.is_public, post_policy=c.post_policy, project_id=c.project_id,
            customer_id=c.customer_ref, archived=c.archived, creator_id=c.creator_id, member_count=sizes.get(c.id, 0),
            is_member=row is not None, my_role=row.role if row else None, muted=bool(row and row.muted),
            pinned=bool(row and row.pinned), unread=cnt.unread if cnt else 0,
            mention_unread=cnt.mentions if cnt else 0, last_message_preview=previews.get(c.id, ""),
            last_message_at=c.last_message_at, last_seq=c.last_seq, last_read_seq=row.last_read_seq if row else 0,
            other_user=user_ref(other) if other else None, members=_members(c) if detail and row else None,
            can=_can(c, row), created_at=c.created_at))
    return out


def file_for(file_id, conv: Conversation) -> File | None:
    return File.objects.filter(pk=file_id, subject_id=conv.subject_id, active=True).first()
