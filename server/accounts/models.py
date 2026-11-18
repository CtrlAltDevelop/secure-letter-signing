import secrets
import uuid

from django.contrib.auth.base_user import BaseUserManager
from django.contrib.auth.models import AbstractUser
from django.db import models
from django.db.models import Q

BASE_PERMISSION = "user"


class Permission(models.Model):
    """Permission catalog. Rows are data: the superuser can add more in the admin."""

    code = models.CharField(max_length=64, unique=True)
    description = models.CharField(max_length=200, blank=True)

    def __str__(self) -> str:
        return self.code


class UserManager(BaseUserManager):
    use_in_migrations = True

    def create_user(self, email: str, password: str | None = None, **extra):
        if not email:
            raise ValueError("Email is required")
        user = self.model(email=self.normalize_email(email).lower(), **extra)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email: str, password: str | None = None, **extra):
        extra.update(is_staff=True, is_superuser=True, email_verified=True)
        return self.create_user(email, password, **extra)


class User(AbstractUser):
    username = None
    email = models.EmailField(unique=True)
    full_name = models.CharField(max_length=150, blank=True)
    title = models.CharField(max_length=100, blank=True)
    department = models.CharField(max_length=100, blank=True)
    email_verified = models.BooleanField(default=False)
    # Exactly one manager per company; only the superuser sets this (in the admin).
    is_manager = models.BooleanField(default=False)
    grants = models.ManyToManyField(Permission, blank=True, related_name="users")

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS: list[str] = []
    objects = UserManager()

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["is_manager"], condition=Q(is_manager=True), name="single_manager"),
        ]

    def has_grant(self, code: str) -> bool:
        return self.grants.filter(code=code).exists()

    def __str__(self) -> str:
        return self.email


class Session(models.Model):
    """One login session. Revoking it kills refresh and access tokens immediately."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.PROTECT, related_name="sessions")
    refresh_hash = models.CharField(max_length=64, unique=True)
    prev_refresh_hash = models.CharField(max_length=64, blank=True, db_index=True)  # detects refresh-token reuse
    device_name = models.CharField(max_length=100, blank=True)
    platform = models.CharField(max_length=30, blank=True)
    ip = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.CharField(max_length=300, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    last_active = models.DateTimeField(auto_now_add=True)
    revoked_at = models.DateTimeField(null=True, blank=True)


def _new_invite_code() -> str:
    return secrets.token_urlsafe(8)


class InviteCode(models.Model):
    code = models.CharField(max_length=32, unique=True, default=_new_invite_code)
    created_by = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    max_uses = models.PositiveIntegerField(default=1)
    uses = models.PositiveIntegerField(default=0)
    expires_at = models.DateTimeField(null=True, blank=True)
    active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)


class CompanySettings(models.Model):
    """Singleton (pk=1). Signup switches: manager or superuser. SMTP: superuser only."""

    signup_domain_enabled = models.BooleanField(default=False)
    allowed_domain = models.CharField(max_length=100, blank=True)
    signup_invite_enabled = models.BooleanField(default=False)

    smtp_host = models.CharField(max_length=200, blank=True)
    smtp_port = models.PositiveIntegerField(default=587)
    smtp_user = models.CharField(max_length=200, blank=True)
    smtp_password = models.CharField(max_length=200, blank=True)
    smtp_use_tls = models.BooleanField(default=True)
    from_email = models.EmailField(blank=True)

    class Meta:
        verbose_name_plural = "company settings"

    @classmethod
    def load(cls) -> "CompanySettings":
        obj, _ = cls.objects.get_or_create(pk=1)
        return obj


class AuditEvent(models.Model):
    """Append-only record of sensitive actions (hash chain is added in Phase 5)."""

    actor = models.ForeignKey(User, null=True, on_delete=models.PROTECT, related_name="+")
    action = models.CharField(max_length=64)
    target = models.CharField(max_length=200, blank=True)
    data = models.JSONField(default=dict, blank=True)
    at = models.DateTimeField(auto_now_add=True)


def audit(actor: User | None, action: str, target: str = "", **data) -> AuditEvent:
    return AuditEvent.objects.create(actor=actor, action=action, target=target, data=data)
