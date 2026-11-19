"""Chat: conversations (group, channel, dm), members, messages. Nothing is deleted (DB triggers refuse DELETE).

Message bodies are encrypted at rest (`workspace.textbox`); a deleted message keeps its row as an empty tombstone.
"""
import uuid

from django.conf import settings
from django.db import models
from django.utils import timezone

User = settings.AUTH_USER_MODEL


class Conversation(models.Model):
    GROUP, CHANNEL, DM = "group", "channel", "dm"
    KINDS = [(GROUP, "Group"), (CHANNEL, "Channel"), (DM, "Direct message")]
    ADMINS, ALL = "admins", "all"
    POLICIES = [(ADMINS, "Admins only"), (ALL, "Everyone")]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    subject = models.OneToOneField("workspace.Subject", on_delete=models.PROTECT, related_name="conversation")
    kind = models.CharField(max_length=10, choices=KINDS)
    name = models.CharField(max_length=100, blank=True)  # empty for a dm (the app shows the other person)
    description = models.CharField(max_length=500, blank=True)
    is_public = models.BooleanField(default=False)
    post_policy = models.CharField(max_length=10, choices=POLICIES, default=ALL)
    creator = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    project = models.OneToOneField("projects.Project", null=True, blank=True, on_delete=models.PROTECT,
                                   related_name="chat")
    customer_ref = models.UUIDField(null=True, blank=True, unique=True)  # crm customer id (bare, like letters links)
    dm_key = models.CharField(max_length=40, null=True, blank=True, unique=True)  # "<low id>:<high id>"
    archived = models.BooleanField(default=False)
    last_seq = models.PositiveIntegerField(default=0)  # highest message seq; bumped under select_for_update
    last_message_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(default=timezone.now)


class ConversationMember(models.Model):
    ADMIN, MEMBER = "admin", "member"
    ROLES = [(ADMIN, "Admin"), (MEMBER, "Member")]

    conversation = models.ForeignKey(Conversation, on_delete=models.PROTECT, related_name="members")
    user = models.ForeignKey(User, on_delete=models.PROTECT, related_name="chat_memberships")
    role = models.CharField(max_length=10, choices=ROLES, default=MEMBER)
    muted = models.BooleanField(default=False)
    pinned = models.BooleanField(default=False)
    joined_at = models.DateTimeField(default=timezone.now)
    last_read_seq = models.PositiveIntegerField(default=0)
    active = models.BooleanField(default=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["conversation", "user"], name="one_chat_member_row")]
        indexes = [models.Index(fields=["user", "active"], name="chat_member_user_active")]


class Message(models.Model):
    TEXT, FILE, VOICE, SYSTEM = "text", "file", "voice", "system"
    KINDS = [(k, k) for k in (TEXT, FILE, VOICE, SYSTEM)]

    conversation = models.ForeignKey(Conversation, on_delete=models.PROTECT, related_name="messages")
    seq = models.PositiveIntegerField()
    author = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    kind = models.CharField(max_length=10, choices=KINDS, default=TEXT)
    body = models.JSONField(default=dict, blank=True)  # {"v":3,"ct":..}; {} once deleted
    reply_to = models.ForeignKey("self", null=True, blank=True, on_delete=models.PROTECT, related_name="replies")
    mentions = models.JSONField(default=list, blank=True)  # user ids, all members when written
    file = models.ForeignKey("workspace.File", null=True, blank=True, on_delete=models.PROTECT, related_name="+")
    created_at = models.DateTimeField(default=timezone.now)
    edited_at = models.DateTimeField(null=True, blank=True)
    deleted = models.BooleanField(default=False)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["conversation", "seq"], name="one_message_per_seq")]
        indexes = [models.Index(fields=["conversation", "created_at"], name="chat_msg_conv_created")]


class PinnedMessage(models.Model):
    conversation = models.ForeignKey(Conversation, on_delete=models.PROTECT, related_name="pins")
    message = models.OneToOneField(Message, on_delete=models.PROTECT, related_name="pin")
    pinned_by = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    at = models.DateTimeField(default=timezone.now)
    active = models.BooleanField(default=True)


class MessageRead(models.Model):
    """Per-message seen-by evidence (only written for conversations with at most 200 members)."""

    message = models.ForeignKey(Message, on_delete=models.PROTECT, related_name="reads")
    user = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    at = models.DateTimeField(default=timezone.now)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["message", "user"], name="one_read_row_per_user")]
        indexes = [models.Index(fields=["user", "message"], name="chat_read_user_message")]


