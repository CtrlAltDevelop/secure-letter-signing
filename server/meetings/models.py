"""Meetings, attendees, resolutions, sealed minutes signatures and templates. Nothing is deleted (DB triggers).

Titles and locations are plaintext (searchable); descriptions and resolution texts are encrypted at rest.
"""
import uuid

from django.conf import settings
from django.db import models
from django.db.models import Q
from django.utils import timezone

User = settings.AUTH_USER_MODEL


class MeetingTemplate(models.Model):
    """`owner` null = organisation template (manager only). `data` = {kind, location, description, attendees:[{user_id, role}]}."""

    owner = models.ForeignKey(User, null=True, blank=True, on_delete=models.PROTECT, related_name="+")
    name = models.CharField(max_length=100)
    data = models.JSONField(default=dict)
    active = models.BooleanField(default=True)
    created_at = models.DateTimeField(default=timezone.now)


class Meeting(models.Model):
    SIMPLE, ORGANIZATIONAL = "simple", "organizational"
    KINDS = [(SIMPLE, SIMPLE), (ORGANIZATIONAL, ORGANIZATIONAL)]
    DRAFT, SCHEDULED, HELD, CLOSED, CANCELLED = "draft", "scheduled", "held", "closed", "cancelled"
    STATUSES = [(s, s) for s in (DRAFT, SCHEDULED, HELD, CLOSED, CANCELLED)]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    subject = models.OneToOneField("workspace.Subject", on_delete=models.PROTECT, related_name="meeting")
    title = models.CharField(max_length=200)
    kind = models.CharField(max_length=15, choices=KINDS, default=SIMPLE)
    location = models.CharField(max_length=200, blank=True)
    starts_at = models.DateTimeField(null=True, blank=True)
    ends_at = models.DateTimeField(null=True, blank=True)
    description = models.JSONField(default=dict, blank=True)  # encrypted via workspace.textbox
    status = models.CharField(max_length=10, choices=STATUSES, default=DRAFT, db_index=True)
    creator = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    project = models.ForeignKey("projects.Project", null=True, blank=True, on_delete=models.PROTECT,
                                related_name="meetings")
    template = models.ForeignKey(MeetingTemplate, null=True, blank=True, on_delete=models.PROTECT, related_name="+")
    customer = models.ForeignKey("crm.Customer", null=True, blank=True, on_delete=models.PROTECT,
                                 related_name="meetings")
    revision = models.PositiveIntegerField(default=1)  # bumped by "reopen"; bound into every signature
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(default=timezone.now)


class MeetingAttendee(models.Model):
    CHAIR, SECRETARY, MEMBER, GUEST = "chair", "secretary", "member", "guest"
    ROLES = [(r, r) for r in (CHAIR, SECRETARY, MEMBER, GUEST)]
    UNKNOWN, PRESENT, ABSENT, EXCUSED = "unknown", "present", "absent", "excused"
    ATTENDANCE = [(a, a) for a in (UNKNOWN, PRESENT, ABSENT, EXCUSED)]

    meeting = models.ForeignKey(Meeting, on_delete=models.PROTECT, related_name="attendees")
    user = models.ForeignKey(User, null=True, blank=True, on_delete=models.PROTECT, related_name="+")
    guest_name = models.CharField(max_length=150, blank=True)  # an external guest has no user
    role = models.CharField(max_length=10, choices=ROLES, default=MEMBER)
    attendance = models.CharField(max_length=10, choices=ATTENDANCE, default=UNKNOWN)
    added_by = models.ForeignKey(User, null=True, on_delete=models.PROTECT, related_name="+")
    active = models.BooleanField(default=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["meeting", "user"], condition=Q(user__isnull=False),
                                    name="one_attendee_row_per_meeting_user"),
            models.UniqueConstraint(fields=["meeting", "guest_name"], condition=Q(user__isnull=True),
                                    name="one_attendee_row_per_meeting_guest"),
        ]


class Resolution(models.Model):
    OPEN, DONE, CANCELLED = "open", "done", "cancelled"
    STATUSES = [(s, s) for s in (OPEN, DONE, CANCELLED)]

    meeting = models.ForeignKey(Meeting, on_delete=models.PROTECT, related_name="resolutions")
    text = models.JSONField(default=dict)  # encrypted via workspace.textbox
    due_at = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=10, choices=STATUSES, default=OPEN)
    task = models.ForeignKey("tasks.Task", null=True, blank=True, on_delete=models.PROTECT, related_name="+")
    active = models.BooleanField(default=True)
    created_by = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    created_at = models.DateTimeField(default=timezone.now)


class ResolutionOwner(models.Model):
    resolution = models.ForeignKey(Resolution, on_delete=models.PROTECT, related_name="owners")
    user = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    active = models.BooleanField(default=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["resolution", "user"], name="one_owner_row_per_resolution")]


class MeetingMinutesSignature(models.Model):
    """Immutable and sealed like a letter signature; `revision` ties it to one version of the minutes."""

    APPROVED, REJECTED = "approved", "rejected"

    meeting = models.ForeignKey(Meeting, on_delete=models.PROTECT, related_name="signatures")
    user = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    revision = models.PositiveIntegerField()
    decision = models.CharField(max_length=10, choices=[(APPROVED, APPROVED), (REJECTED, REJECTED)])
    note = models.TextField(blank=True)
    method = models.CharField(max_length=10, choices=[("pin", "pin"), ("biometric", "biometric")])
    payload = models.JSONField()
    seal = models.TextField()
    nonce = models.CharField(max_length=64, unique=True)
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["meeting", "user", "revision"],
                                               name="one_signature_per_user_revision")]
