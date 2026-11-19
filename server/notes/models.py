"""Personal notes. Visible to the owner only. Titles plaintext, body encrypted at rest. Nothing is deleted."""
import uuid

from django.conf import settings
from django.db import models
from django.utils import timezone

User = settings.AUTH_USER_MODEL


class Note(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    subject = models.OneToOneField("workspace.Subject", on_delete=models.PROTECT, related_name="note")
    owner = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    title = models.CharField(max_length=200, blank=True)
    body = models.JSONField(default=dict, blank=True)  # encrypted via workspace.textbox
    color = models.PositiveSmallIntegerField(default=0)  # 0-15
    pinned = models.BooleanField(default=False)
    archived = models.BooleanField(default=False)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(default=timezone.now)


class NoteChecklistItem(models.Model):
    note = models.ForeignKey(Note, on_delete=models.PROTECT, related_name="checklist")
    text = models.CharField(max_length=300)
    done = models.BooleanField(default=False)
    rank = models.BigIntegerField(default=0)
    active = models.BooleanField(default=True)
