import uuid

from django.conf import settings
from django.db import models
from django.utils import timezone


class UserKey(models.Model):
    """One public key pair per device. History is never overwritten: a new key is a new row."""

    PENDING, ACTIVE, RETIRED = "pending", "active", "retired"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="keys")
    device_name = models.CharField(max_length=100, blank=True)
    sign_pub = models.JSONField()
    enc_pub = models.JSONField()
    fingerprint = models.CharField(max_length=39, unique=True)
    status = models.CharField(max_length=10, choices=[(s, s) for s in (PENDING, ACTIVE, RETIRED)], default=PENDING)
    created_at = models.DateTimeField(default=timezone.now)
    approved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.PROTECT, related_name="+"
    )
    approved_at = models.DateTimeField(null=True, blank=True)
    retired_at = models.DateTimeField(null=True, blank=True)


class CompanyKeyVersion(models.Model):
    """Symmetric company key for public letters; the server only stores copies wrapped per user key."""

    version = models.PositiveIntegerField(primary_key=True)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="+")
    created_at = models.DateTimeField(default=timezone.now)


class CompanyKeyWrap(models.Model):
    version = models.ForeignKey(CompanyKeyVersion, on_delete=models.PROTECT, related_name="wraps")
    key = models.ForeignKey(UserKey, on_delete=models.PROTECT, related_name="company_wraps")
    wrap = models.JSONField()

    class Meta:
        constraints = [models.UniqueConstraint(fields=["version", "key"], name="one_company_wrap_per_key")]
