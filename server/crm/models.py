"""Customer files, their members, the append-only timeline and call reports. Nothing is deleted (DB triggers).

Name, phone, mobile, email and national id are plaintext (searchable); address, notes and summaries are encrypted.
"""
import uuid

from django.conf import settings
from django.db import models
from django.utils import timezone

User = settings.AUTH_USER_MODEL


class Customer(models.Model):
    PERSON, COMPANY = "person", "company"
    KINDS = [(PERSON, PERSON), (COMPANY, COMPANY)]
    ACTIVE, INACTIVE, ARCHIVED = "active", "inactive", "archived"
    STATUSES = [(s, s) for s in (ACTIVE, INACTIVE, ARCHIVED)]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    subject = models.OneToOneField("workspace.Subject", on_delete=models.PROTECT, related_name="customer")
    kind = models.CharField(max_length=10, choices=KINDS, default=PERSON, db_index=True)
    name = models.CharField(max_length=200, db_index=True)
    legal_name = models.CharField(max_length=200, blank=True)
    national_id = models.CharField(max_length=20, blank=True, db_index=True)
    registration_no = models.CharField(max_length=30, blank=True)
    phone = models.CharField(max_length=30, blank=True)
    mobile = models.CharField(max_length=30, blank=True)
    email = models.CharField(max_length=254, blank=True, db_index=True)
    address = models.JSONField(default=dict, blank=True)  # encrypted via workspace.textbox
    notes = models.JSONField(default=dict, blank=True)  # encrypted via workspace.textbox
    status = models.CharField(max_length=10, choices=STATUSES, default=ACTIVE, db_index=True)
    owner = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(default=timezone.now)


class CustomerMember(models.Model):
    MANAGER, MEMBER, VIEWER = "manager", "member", "viewer"
    ROLES = [(r, r) for r in (MANAGER, MEMBER, VIEWER)]

    customer = models.ForeignKey(Customer, on_delete=models.PROTECT, related_name="members")
    user = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    role = models.CharField(max_length=10, choices=ROLES, default=MEMBER)
    active = models.BooleanField(default=True)
    added_by = models.ForeignKey(User, null=True, on_delete=models.PROTECT, related_name="+")
    at = models.DateTimeField(default=timezone.now)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["customer", "user"], name="one_member_row_per_customer_user")]


class CustomerEvent(models.Model):
    """Append-only timeline row. `summary` is encrypted; `by` is null for events nobody triggered directly."""

    KINDS = ("note", "call", "meeting", "task", "letter", "finance", "lead", "system")

    customer = models.ForeignKey(Customer, on_delete=models.PROTECT, related_name="events")
    kind = models.CharField(max_length=10, choices=[(k, k) for k in KINDS])
    summary = models.JSONField(default=dict)
    at = models.DateTimeField(default=timezone.now, db_index=True)
    by = models.ForeignKey(User, null=True, blank=True, on_delete=models.PROTECT, related_name="+")
    ref_subject = models.ForeignKey("workspace.Subject", null=True, blank=True, on_delete=models.PROTECT,
                                    related_name="+")


class CallReport(models.Model):
    """Append-only record of a phone call with (or about) a customer."""

    IN, OUT = "in", "out"

    customer = models.ForeignKey(Customer, on_delete=models.PROTECT, related_name="calls")
    direction = models.CharField(max_length=3, choices=[(IN, IN), (OUT, OUT)])
    contact_name = models.CharField(max_length=150, blank=True)
    summary = models.JSONField(default=dict)  # encrypted via workspace.textbox
    at = models.DateTimeField(default=timezone.now)
    duration_s = models.PositiveIntegerField(default=0)
    by = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
