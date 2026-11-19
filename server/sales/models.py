"""Sales leads. Nothing is deleted (won/lost/reopen are status changes). Title, value and probability are plaintext
so they can be aggregated; description and lost reason are encrypted."""
import uuid

from django.conf import settings
from django.db import models
from django.db.models import Q
from django.utils import timezone

User = settings.AUTH_USER_MODEL


class Lead(models.Model):
    OPEN, WON, LOST = "open", "won", "lost"
    STATUSES = [(s, s) for s in (OPEN, WON, LOST)]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    subject = models.OneToOneField("workspace.Subject", on_delete=models.PROTECT, related_name="lead")
    customer = models.ForeignKey("crm.Customer", null=True, blank=True, on_delete=models.PROTECT,
                                 related_name="leads")
    title = models.CharField(max_length=200, db_index=True)
    value = models.BigIntegerField(default=0)  # rials
    probability = models.PositiveSmallIntegerField(default=50)  # 0..100
    owner = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")  # the follow-up person
    description = models.JSONField(default=dict, blank=True)  # encrypted via workspace.textbox
    status = models.CharField(max_length=10, choices=STATUSES, default=OPEN, db_index=True)
    closed_at = models.DateTimeField(null=True, blank=True)
    lost_reason = models.JSONField(default=dict, blank=True)  # encrypted via workspace.textbox
    created_by = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(default=timezone.now)

    class Meta:
        constraints = [
            models.CheckConstraint(condition=Q(probability__lte=100), name="lead_probability_max_100"),
            models.CheckConstraint(condition=Q(value__gte=0), name="lead_value_not_negative"),
        ]
