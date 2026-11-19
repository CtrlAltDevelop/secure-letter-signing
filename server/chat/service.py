"""Conversation lifecycle: create, dm, edit, members, join/leave. Nothing is deleted (members are deactivated)."""
from uuid import UUID

from django.db import IntegrityError, transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja.errors import HttpError

from accounts import guests
from accounts.models import User, audit
from accounts.notify import notify
from workspace.models import Subject
from workspace.registry import require_module

from . import events, mirror, rules
from .models import Conversation, ConversationMember
from .schemas import ConversationIn, ConversationPatch, MemberIn

ADMIN, MEMBER = ConversationMember.ADMIN, ConversationMember.MEMBER
GROUP_PERMISSION = "chat.create_group"


def gate() -> None:
    require_module("chat")


def load(user: User, conversation_id: UUID, *, member_only: bool = True) -> Conversation:
    """The conversation, 404 unless the caller is an active member (or, with `member_only=False`, it is public)."""
    gate()
    conv = get_object_or_404(Conversation.objects.select_related("subject"), pk=conversation_id)
    if mirror.is_mirrored(conv):
        mirror.sync(conv)
    if rules.member_row(user, conv) is None and (member_only or not _discoverable(conv)):
        raise HttpError(404, "Not found")
    return conv


def _discoverable(conv: Conversation) -> bool:
    return conv.is_public and conv.kind != Conversation.DM and not mirror.is_mirrored(conv)


def require_admin(user: User, conv: Conversation) -> None:
    row = rules.member_row(user, conv)
    if row is None or row.role != ADMIN:
        raise HttpError(403, "Permission denied")


def _active_users(ids: list[int], actor: User) -> dict[int, User]:
    users = {u.id: u for u in User.objects.filter(pk__in=set(ids), is_active=True)}
    if len(users) != len(set(ids)) or guests.referable_ids(actor, set(ids)) != set(ids):
        raise HttpError(422, "Unknown or inactive user")
    return users


def _new_conversation(user: User, **fields) -> Conversation:
    subject = Subject.objects.create(module="chat", kind="conversation")
    return Conversation.objects.create(subject=subject, creator=user, **fields)


@transaction.atomic
def create_conversation(user: User, data: ConversationIn) -> Conversation:
    gate()
    if not user.has_grant(GROUP_PERMISSION):
        raise HttpError(403, "Permission denied")
    others = [i for i in dict.fromkeys(data.member_ids) if i != user.id]
    users = _active_users(others, user)
    policy = data.post_policy or (Conversation.ADMINS if data.kind == Conversation.CHANNEL else Conversation.ALL)
    conv = _new_conversation(user, kind=data.kind, name=data.name.strip(), description=data.description.strip(),
                             is_public=data.is_public, post_policy=policy)
    ConversationMember.objects.create(conversation=conv, user=user, role=ADMIN)
    ConversationMember.objects.bulk_create([ConversationMember(conversation=conv, user=u) for u in users.values()])
    audit(user, "chat_conversation_created", str(conv.id), kind=conv.kind, members=len(users) + 1)
    _announce(conv, user, list(users))
    return conv


def _announce(conv: Conversation, actor: User, added: list[int]) -> None:
    if not added:
        return
    events.member_added(conv, added, actor)
    users = User.objects.filter(pk__in=added, is_active=True)
    notify(users, "chat.added", conv.name, conversation_id=str(conv.id), module="chat",
           subject_id=str(conv.subject_id))


def dm_key(a: int, b: int) -> str:
    return f"{min(a, b)}:{max(a, b)}"


def open_dm(user: User, other_id: int) -> Conversation:
    gate()
    if other_id == user.id:
        raise HttpError(422, "Cannot message yourself")
    other = _active_users([other_id], user)[other_id]
    key = dm_key(user.id, other.id)
    for _ in range(2):
        conv = Conversation.objects.filter(dm_key=key).select_related("subject").first()
        if conv:
            return conv
        try:
            with transaction.atomic():
                conv = _new_conversation(user, kind=Conversation.DM, dm_key=key, post_policy=Conversation.ALL)
                ConversationMember.objects.bulk_create(
                    [ConversationMember(conversation=conv, user=u) for u in (user, other)])
                return conv
        except IntegrityError:  # the other side created it at the same moment
            continue
    raise HttpError(409, "Could not open the conversation; try again")


@transaction.atomic
def update_conversation(user: User, conv: Conversation, data: ConversationPatch) -> Conversation:
    require_admin(user, conv)
    if conv.kind == Conversation.DM:
        raise HttpError(422, "A direct message cannot be edited")
    fields = data.dict(exclude_unset=True)
    if "name" in fields:
        conv.name = fields["name"].strip()
    for key in ("description", "is_public", "post_policy", "archived"):
        if fields.get(key) is not None:
            setattr(conv, key, fields[key].strip() if key == "description" else fields[key])
    if mirror.is_mirrored(conv) and fields.get("is_public"):
        raise HttpError(422, "A project or customer chat cannot be public")
    conv.save()
    audit(user, "chat_conversation_updated", str(conv.id), fields=sorted(fields))
    return conv


def _check_roster(conv: Conversation, members: list[MemberIn], actor: User) -> dict[int, str]:
    if conv.kind == Conversation.DM or mirror.is_mirrored(conv):
        raise HttpError(422, "The members of this conversation cannot be edited")
    wanted: dict[int, str] = {}
    for m in members:
        wanted[m.user_id] = m.role
    if ADMIN not in wanted.values():
        raise HttpError(422, "At least one admin is required")
    _active_users(list(wanted), actor)
    return wanted


@transaction.atomic
def set_members(user: User, conv: Conversation, members: list[MemberIn]) -> list[int]:
    require_admin(user, conv)
    wanted = _check_roster(conv, members, user)
    rows = {m.user_id: m for m in ConversationMember.objects.filter(conversation=conv)}
    added: list[int] = []
    for uid, role in wanted.items():
        row = rows.get(uid)
        if row is None:
            ConversationMember.objects.create(conversation=conv, user_id=uid, role=role)
            added.append(uid)
        elif not row.active or row.role != role:
            added += [uid] if not row.active else []
            ConversationMember.objects.filter(pk=row.pk).update(active=True, role=role,
                                                                 joined_at=timezone.now() if not row.active else row.joined_at)
    for uid, row in rows.items():
        if uid not in wanted and row.active:
            ConversationMember.objects.filter(pk=row.pk).update(active=False)
    audit(user, "chat_members_changed", str(conv.id), added=len(added), total=len(wanted))
    _announce(conv, user, added)
    return added


@transaction.atomic
def join(user: User, conv: Conversation) -> Conversation:
    if not _discoverable(conv) or conv.archived:
        raise HttpError(404, "Not found")
    row = ConversationMember.objects.filter(conversation=conv, user=user).first()
    if row is None:
        ConversationMember.objects.create(conversation=conv, user=user, last_read_seq=conv.last_seq)
    elif not row.active:
        ConversationMember.objects.filter(pk=row.pk).update(active=True, role=MEMBER, joined_at=timezone.now(),
                                                             last_read_seq=conv.last_seq)
    else:
        return conv
    events.member_added(conv, [user.id], user)
    return conv


@transaction.atomic
def leave(user: User, conv: Conversation) -> None:
    if conv.kind == Conversation.DM or mirror.is_mirrored(conv):
        raise HttpError(422, "You cannot leave this conversation")
    ConversationMember.objects.filter(conversation=conv, user=user).update(active=False)
    remaining = rules.active_members(conv).order_by("joined_at", "id")
    if remaining.exists() and not remaining.filter(role=ADMIN).exists():
        ConversationMember.objects.filter(pk=remaining.first().pk).update(role=ADMIN)


def set_flag(user: User, conv: Conversation, **flags: bool) -> None:
    ConversationMember.objects.filter(conversation=conv, user=user, active=True).update(**flags)
