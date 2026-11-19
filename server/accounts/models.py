import hashlib
import hmac
import json
import secrets
import uuid

from django.conf import settings
from django.contrib.auth.base_user import BaseUserManager
from django.contrib.auth.models import AbstractUser
from django.db import IntegrityError, models, transaction
from django.db.models import Q
from django.utils import timezone

BASE_PERMISSION = "user"
# Granted to every new user (signup, invite, CSV import); existing users got the extras in a workspace migration.
DEFAULT_GRANTS = (BASE_PERMISSION, "task.create", "project.create", "customer.create", "chat.create_group")


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


class Department(models.Model):
    """Company departments. Managed by the manager only (API); never deleted, only deactivated."""

    name = models.CharField(max_length=100, unique=True)
    active = models.BooleanField(default=True)

    class Meta:
        ordering = ("name",)

    def __str__(self) -> str:
        return self.name


class OrgTitle(models.Model):
    """Company job positions ('titles'). Managed by the manager only; never deleted, only deactivated."""

    name = models.CharField(max_length=100, unique=True)
    active = models.BooleanField(default=True)

    class Meta:
        ordering = ("name",)

    def __str__(self) -> str:
        return self.name


class User(AbstractUser):
    username = None
    email = models.EmailField(unique=True)
    full_name = models.CharField(max_length=150, blank=True)
    title = models.CharField(max_length=100, blank=True)
    department = models.ForeignKey(Department, null=True, blank=True, on_delete=models.PROTECT, related_name="users")
    email_verified = models.BooleanField(default=False)
    # Exactly one manager per company; only the superuser sets this (in the admin).
    is_manager = models.BooleanField(default=False)
    grants = models.ManyToManyField(Permission, blank=True, related_name="users")
    # 6-digit signing PIN, hashed with the Django password hasher. Empty = not set yet.
    signing_pin_hash = models.CharField(max_length=256, blank=True)
    phone = models.CharField(max_length=20, null=True, blank=True)  # mobile number for SMS (meetings)
    org_title = models.ForeignKey(OrgTitle, null=True, blank=True, on_delete=models.PROTECT, related_name="users")
    status_text = models.CharField(max_length=80, blank=True)  # short status message shown next to the name
    # Two-factor login (TOTP). The secret is Fernet-encrypted with the data key; see accounts/twofactor.py.
    totp_secret = models.TextField(blank=True)
    totp_enabled = models.BooleanField(default=False)
    # Guests: external collaborators limited to tasks/projects/chat they were explicitly added to (accounts/guests.py).
    is_guest = models.BooleanField(default=False)
    guest_expires_at = models.DateTimeField(null=True, blank=True)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS: list[str] = []
    objects = UserManager()

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["is_manager"], condition=Q(is_manager=True), name="single_manager"),
            models.CheckConstraint(condition=~Q(is_guest=True, is_manager=True), name="guest_is_not_manager"),
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
    prev_refresh_hash = models.CharField(max_length=64, blank=True)  # immediate predecessor: retry grace window
    rotated_at = models.DateTimeField(default=timezone.now)
    device_name = models.CharField(max_length=100, blank=True)
    platform = models.CharField(max_length=30, blank=True)
    ip = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.CharField(max_length=300, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    last_active = models.DateTimeField(auto_now_add=True)
    revoked_at = models.DateTimeField(null=True, blank=True)
    # Set by the app that created the session: it can confirm a fingerprint/face check locally.
    biometric = models.BooleanField(default=False)


class RetiredRefresh(models.Model):
    """Every refresh token that was rotated away. Presenting one again means it was copied."""

    token_hash = models.CharField(max_length=64, primary_key=True)
    session = models.ForeignKey(Session, on_delete=models.CASCADE, related_name="retired")
    retired_at = models.DateTimeField(auto_now_add=True)


def _new_invite_code() -> str:
    return secrets.token_urlsafe(8)


class InviteCode(models.Model):
    code = models.CharField(max_length=32, unique=True, default=_new_invite_code)
    created_by = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    max_uses = models.PositiveIntegerField(default=1, null=True, blank=True, help_text="Leave empty for unlimited uses")
    uses = models.PositiveIntegerField(default=0)
    expires_at = models.DateTimeField(null=True, blank=True)
    active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    # Applied to everyone who signs up with this code (the base "user" grant is always given).
    grants = models.ManyToManyField(Permission, blank=True, related_name="invites")
    department = models.ForeignKey(Department, null=True, blank=True, on_delete=models.PROTECT, related_name="+")
    # Guest invites create guest accounts (no grants besides the base one), optionally expiring.
    guest = models.BooleanField(default=False)
    guest_expires_at = models.DateTimeField(null=True, blank=True)


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

    require_2fa = models.BooleanField(default=False)  # users without 2FA are told to set it up (still log in)

    # Printed letter header/footer, filled by the manager. Public to every signed-in user (not secret).
    letterhead = models.JSONField(default=dict, blank=True)

    class Meta:
        verbose_name_plural = "company settings"

    @classmethod
    def load(cls) -> "CompanySettings":
        obj, _ = cls.objects.get_or_create(pk=1)
        return obj


class RecoveryCode(models.Model):
    """One-time 2FA recovery code (Django hasher). A used or replaced code has `used_at`; rows are never deleted."""

    user = models.ForeignKey(User, on_delete=models.PROTECT, related_name="recovery_codes")
    hash = models.CharField(max_length=256)
    used_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(default=timezone.now)


class LoginEvent(models.Model):
    """Append-only login attempt log (the database refuses UPDATE and DELETE). `user` is null for unknown emails."""

    user = models.ForeignKey(User, null=True, blank=True, on_delete=models.PROTECT, related_name="login_events")
    email_tried = models.CharField(max_length=254, blank=True)
    at = models.DateTimeField(default=timezone.now, db_index=True)
    ip = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.CharField(max_length=300, blank=True)
    success = models.BooleanField(default=False)
    device_name = models.CharField(max_length=100, blank=True)
    reason = models.CharField(max_length=40, blank=True)  # bad_password, bad_code, expired_guest, locked, ...

    class Meta:
        indexes = [models.Index(fields=["user", "-at"], name="loginevent_user_at")]


GENESIS_HASH = "0" * 64


class AuditEvent(models.Model):
    """Append-only, hash-chained record of sensitive actions. Verify with `verify_audit_chain`."""

    actor = models.ForeignKey(User, null=True, on_delete=models.PROTECT, related_name="+")
    action = models.CharField(max_length=64)
    target = models.CharField(max_length=200, blank=True)
    data = models.JSONField(default=dict, blank=True)
    at = models.DateTimeField(default=timezone.now)
    prev_hash = models.CharField(max_length=64, blank=True)
    hash = models.CharField(max_length=64, blank=True)  # empty only on rows from before the chain existed

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["prev_hash"], condition=~Q(hash=""), name="audit_chain_is_linear"),
        ]


def audit_digest(prev_hash: str, actor_id, action: str, target: str, data: dict, at) -> str:
    from core.cryptoutil import canonical_json

    body = canonical_json(
        {"a": actor_id, "act": action, "t": target, "d": json.loads(json.dumps(data, default=str)), "at": at.isoformat()}
    )
    # Keyed: someone who can edit the database but lacks SECRET_KEY cannot recompute a valid chain.
    key = hashlib.sha256(b"audit-chain:" + settings.SECRET_KEY.encode()).digest()
    return hmac.new(key, (prev_hash + body).encode(), hashlib.sha256).hexdigest()


def audit(actor: User | None, action: str, target: str = "", **data) -> AuditEvent:
    for _ in range(5):  # a concurrent writer taking the same predecessor loses the unique constraint and retries
        try:
            with transaction.atomic():
                last = AuditEvent.objects.exclude(hash="").order_by("-id").select_for_update().first()
                prev = last.hash if last else GENESIS_HASH
                at = timezone.now()
                digest = audit_digest(prev, actor.id if actor else None, action, target, data, at)
                return AuditEvent.objects.create(
                    actor=actor, action=action, target=target, data=data, at=at, prev_hash=prev, hash=digest
                )
        except IntegrityError:
            continue
    raise RuntimeError("could not append to the audit chain")


def verify_audit_chain() -> int | None:
    """Id of the first tampered/missing row, or None when the chain is intact."""
    prev = None
    for ev in AuditEvent.objects.exclude(hash="").order_by("id").iterator():
        if prev is not None and ev.prev_hash != prev:
            return ev.id
        if prev is None and ev.prev_hash != GENESIS_HASH:
            return ev.id
        if audit_digest(ev.prev_hash, ev.actor_id, ev.action, ev.target, ev.data, ev.at) != ev.hash:
            return ev.id
        prev = ev.hash
    return None


class Notification(models.Model):
    """In-app notification. Carries the letter title only, never content."""

    user = models.ForeignKey(User, on_delete=models.PROTECT, related_name="notifications")
    kind = models.CharField(max_length=40)
    title = models.CharField(max_length=300)
    data = models.JSONField(default=dict, blank=True)
    at = models.DateTimeField(default=timezone.now)
    read_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-id"]


def background_path(instance: "UserPrefs", filename: str) -> str:
    return f"backgrounds/{instance.user_id}"


class UserPrefs(models.Model):
    """Per-user preferences, created lazily. The background image is Fernet-encrypted on disk."""

    THEMES = [(t, t) for t in ("light", "dark", "auto")]

    user = models.OneToOneField(User, on_delete=models.PROTECT, related_name="prefs")
    theme = models.CharField(max_length=5, choices=THEMES, default="auto")
    birthday = models.DateField(null=True, blank=True)
    birthday_visible = models.BooleanField(default=True)
    dnd_until = models.DateTimeField(null=True, blank=True)
    personal_email = models.EmailField(blank=True)
    personal_email_verified = models.BooleanField(default=False)
    background = models.FileField(upload_to=background_path, blank=True)
    background_type = models.CharField(max_length=20, blank=True)
    background_active = models.BooleanField(default=False)


class DailyRun(models.Model):
    """Guard row: a named daily job runs once per Tehran-local date (the unique constraint is the lock)."""

    name = models.CharField(max_length=40)
    date = models.DateField()

    class Meta:
        constraints = [models.UniqueConstraint(fields=["name", "date"], name="one_daily_run_per_name_date")]
