"""Shared workspace models, anchored on `Subject`. Nothing is deleted (DB triggers, see the migrations).

Titles and names are plaintext (searchable); descriptions, comments and files are encrypted at rest.
"""
import uuid

from django.conf import settings
from django.db import models
from django.db.models import Q
from django.utils import timezone

User = settings.AUTH_USER_MODEL


class Subject(models.Model):
    """Anchor for anything that carries labels, comments, files and history. Module rows point to it one to one."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    module = models.CharField(max_length=32, db_index=True)
    kind = models.CharField(max_length=32)
    created_at = models.DateTimeField(default=timezone.now)


class Label(models.Model):
    ORG, PERSONAL = "org", "personal"
    SCOPES = [(ORG, "Organisation"), (PERSONAL, "Personal")]

    scope = models.CharField(max_length=10, choices=SCOPES)
    owner = models.ForeignKey(User, null=True, blank=True, on_delete=models.PROTECT, related_name="labels")
    name = models.CharField(max_length=60)
    color = models.PositiveSmallIntegerField(default=0)
    active = models.BooleanField(default=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["owner", "name"], name="label_unique_per_owner"),
            models.UniqueConstraint(fields=["name"], condition=Q(owner__isnull=True), name="label_unique_org_name"),
        ]


class SubjectLabel(models.Model):
    subject = models.ForeignKey(Subject, on_delete=models.PROTECT, related_name="subject_labels")
    label = models.ForeignKey(Label, on_delete=models.PROTECT, related_name="subject_labels")
    added_by = models.ForeignKey(User, null=True, on_delete=models.PROTECT, related_name="+")
    at = models.DateTimeField(default=timezone.now)
    active = models.BooleanField(default=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["subject", "label"], name="one_label_row_per_subject")]


def file_path(instance: "File", filename: str) -> str:
    return f"workspace/{instance.id}"


class File(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    subject = models.ForeignKey(Subject, on_delete=models.PROTECT, related_name="files")
    uploaded_by = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    name = models.CharField(max_length=200)
    content_type = models.CharField(max_length=100)
    size = models.PositiveBigIntegerField()  # plaintext size; the blob on disk is Fernet-encrypted
    sha256_plain = models.CharField(max_length=64)
    blob = models.FileField(upload_to=file_path)
    active = models.BooleanField(default=True)
    created_at = models.DateTimeField(default=timezone.now)


class Comment(models.Model):
    COMMENT, REPORT = "comment", "report"
    KINDS = [(COMMENT, "Comment"), (REPORT, "Report")]

    subject = models.ForeignKey(Subject, on_delete=models.PROTECT, related_name="comments")
    author = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    parent = models.ForeignKey("self", null=True, blank=True, on_delete=models.PROTECT, related_name="replies")
    kind = models.CharField(max_length=10, choices=KINDS, default=COMMENT)
    body = models.JSONField(default=dict)  # {"v":3,"ct":<Fernet token>} via core.cryptoutil.encrypt_body
    progress_snapshot = models.PositiveSmallIntegerField(null=True, blank=True)
    replaces = models.ForeignKey("self", null=True, blank=True, on_delete=models.PROTECT, related_name="replacements")
    active = models.BooleanField(default=True)
    created_at = models.DateTimeField(default=timezone.now)


class Mention(models.Model):
    """`user` was mentioned in `comment` (a comment row is never edited; an edit copies its mentions)."""

    comment = models.ForeignKey(Comment, on_delete=models.PROTECT, related_name="mentions")
    user = models.ForeignKey(User, on_delete=models.PROTECT, related_name="mentions")

    class Meta:
        constraints = [models.UniqueConstraint(fields=["comment", "user"], name="one_mention_per_comment_user")]
        indexes = [models.Index(fields=["user", "-comment"], name="mention_user_comment")]


class ChangeHistory(models.Model):
    """Append-only. Encrypted fields record `{"changed": true}` instead of values."""

    subject = models.ForeignKey(Subject, on_delete=models.PROTECT, related_name="history")
    actor = models.ForeignKey(User, null=True, on_delete=models.PROTECT, related_name="+")
    field = models.CharField(max_length=64)
    old = models.JSONField(null=True)
    new = models.JSONField(null=True)
    at = models.DateTimeField(default=timezone.now)


class SeenBy(models.Model):
    subject = models.ForeignKey(Subject, on_delete=models.PROTECT, related_name="seen_by")
    user = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    first_at = models.DateTimeField(default=timezone.now)
    last_at = models.DateTimeField(default=timezone.now)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["subject", "user"], name="one_seen_row_per_user")]


class Event(models.Model):
    """Live-update log of the workspace stream; its id is the catch-up cursor. Append-only."""

    module = models.CharField(max_length=32)
    kind = models.CharField(max_length=40)
    subject = models.ForeignKey(Subject, null=True, on_delete=models.PROTECT, related_name="events")
    title = models.CharField(max_length=300, blank=True)
    actor = models.ForeignKey(User, null=True, on_delete=models.PROTECT, related_name="+")
    data = models.JSONField(default=dict)
    at = models.DateTimeField(default=timezone.now)


class EventRecipient(models.Model):
    """Who may see an event, decided when it is written (visibility changes later do not rewrite history)."""

    event = models.ForeignKey(Event, on_delete=models.PROTECT, related_name="recipients")
    user = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")

    class Meta:
        constraints = [models.UniqueConstraint(fields=["event", "user"], name="one_recipient_row_per_event")]
        indexes = [models.Index(fields=["user", "event"], name="recipient_user_event")]


class Reminder(models.Model):
    """`rule` = {freq: daily|weekly|monthly_jalali, interval, weekdays, day}; `next_at` is UTC (Phase 6 computes it)."""

    subject = models.ForeignKey(Subject, on_delete=models.PROTECT, related_name="reminders")
    user = models.ForeignKey(User, on_delete=models.PROTECT, related_name="reminders")
    created_by = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    next_at = models.DateTimeField(db_index=True)
    rule = models.JSONField(null=True, blank=True)
    active = models.BooleanField(default=True)
    last_fired_at = models.DateTimeField(null=True, blank=True)


class Holiday(models.Model):
    """A non-working day shown on calendars. Deactivated, never deleted. Titles are public to every colleague."""

    OFFICIAL, RELIGIOUS, COMPANY = "official", "religious", "company"
    KINDS = [(OFFICIAL, OFFICIAL), (RELIGIOUS, RELIGIOUS), (COMPANY, COMPANY)]

    date = models.DateField(db_index=True)
    title = models.CharField(max_length=100)
    kind = models.CharField(max_length=10, choices=KINDS, default=OFFICIAL)
    active = models.BooleanField(default=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["date", "title"], name="one_holiday_title_per_date")]


class Bookmark(models.Model):
    """A user's bookmark. Subject-backed targets store the subject id in `target_id`; chat messages store the message
    id (not a subject). `note` is encrypted via workspace.textbox. Deactivated, never deleted."""

    user = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    target_module = models.CharField(max_length=32)
    target_id = models.CharField(max_length=64)
    subject = models.ForeignKey(Subject, null=True, blank=True, on_delete=models.PROTECT, related_name="+")
    title = models.CharField(max_length=200, blank=True)
    note = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(default=timezone.now)
    active = models.BooleanField(default=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["user", "target_module", "target_id"],
                                               name="one_bookmark_per_user_target")]


class Pin(models.Model):
    """A subject (project, customer file, conversation) pinned to a user's shortcuts."""

    user = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    subject = models.ForeignKey(Subject, on_delete=models.PROTECT, related_name="+")
    rank = models.BigIntegerField(default=0)
    active = models.BooleanField(default=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["user", "subject"], name="one_pin_per_user_subject")]
