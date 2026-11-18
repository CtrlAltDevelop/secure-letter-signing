import uuid

from django.conf import settings
from django.db import models
from django.utils import timezone

User = settings.AUTH_USER_MODEL


class Letter(models.Model):
    """`body` is stored encrypted at rest: {"v": 3, "ct": <Fernet token of the canonical JSON body>}."""

    DRAFT, IN_SIGNING, PUBLISHED, REJECTED, CANCELLED = "draft", "in_signing", "published", "rejected", "cancelled"
    STATUSES = [(s, s) for s in (DRAFT, IN_SIGNING, PUBLISHED, REJECTED, CANCELLED)]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    no = models.PositiveIntegerField(unique=True)
    title = models.CharField(max_length=200)
    creator = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    parent = models.ForeignKey("self", null=True, blank=True, on_delete=models.PROTECT, related_name="children")
    status = models.CharField(max_length=12, choices=STATUSES, default=DRAFT)
    visibility = models.CharField(max_length=7, choices=[("public", "public"), ("private", "private")])
    publish_mode = models.CharField(max_length=10, choices=[("now", "now"), ("after_sign", "after_sign")])
    order = models.CharField(max_length=8, choices=[("parallel", "parallel"), ("serial", "serial")])
    due_at = models.DateTimeField(null=True, blank=True)
    body = models.JSONField()  # {"v": 3, "ct": "<Fernet token>"}; see core.cryptoutil.encrypt_body
    unlisted = models.BooleanField(default=False)
    created_at = models.DateTimeField(default=timezone.now)
    sent_at = models.DateTimeField(null=True, blank=True)
    shown_at = models.DateTimeField(null=True, blank=True)  # when viewers (not just signers) may see it
    closed_at = models.DateTimeField(null=True, blank=True)


class Participant(models.Model):
    SIGNER, VIEWER = "signer", "viewer"

    letter = models.ForeignKey(Letter, on_delete=models.PROTECT, related_name="participants")
    user = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    role = models.CharField(max_length=6, choices=[(SIGNER, SIGNER), (VIEWER, VIEWER)])
    position = models.PositiveIntegerField(default=0)
    decision = models.CharField(max_length=8, blank=True)  # approved | rejected
    decided_at = models.DateTimeField(null=True, blank=True)
    opened_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["letter", "user"], name="one_role_per_user_per_letter")]


class Signature(models.Model):
    """Immutable (DB trigger). `payload` is exactly what the server sealed; `seal` is the Ed25519 signature."""

    letter = models.ForeignKey(Letter, on_delete=models.PROTECT, related_name="signatures")
    signer = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    decision = models.CharField(max_length=8)
    payload = models.JSONField()
    seal = models.CharField(max_length=128)
    method = models.CharField(max_length=10, choices=[("pin", "pin"), ("biometric", "biometric")])
    nonce = models.CharField(max_length=64, unique=True)
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["letter", "signer"], name="one_signature_per_signer")]


class SignRequest(models.Model):
    """A session without biometrics asks another biometric session of the same user to approve a signature."""

    PENDING, APPROVED, DECLINED, CANCELLED, EXPIRED = "pending", "approved", "declined", "cancelled", "expired"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    letter = models.ForeignKey(Letter, on_delete=models.PROTECT, related_name="sign_requests")
    user = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    requester_session = models.ForeignKey("accounts.Session", on_delete=models.PROTECT, related_name="+")
    approver_session = models.ForeignKey("accounts.Session", on_delete=models.PROTECT, related_name="+")
    decision = models.CharField(max_length=8)
    note = models.CharField(max_length=2000, blank=True)
    status = models.CharField(max_length=10, default=PENDING)
    created_at = models.DateTimeField(default=timezone.now)
    expires_at = models.DateTimeField()
    resolved_at = models.DateTimeField(null=True, blank=True)


def attachment_path(instance, filename: str) -> str:
    return f"letters/{instance.letter_id}/{instance.id}.bin"


class Attachment(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    letter = models.ForeignKey(Letter, on_delete=models.PROTECT, related_name="attachments")
    content_type = models.CharField(max_length=40)
    label = models.CharField(max_length=100, blank=True)
    size = models.PositiveIntegerField()  # plaintext size; the file on disk is Fernet-encrypted
    file = models.FileField(upload_to=attachment_path)
    created_at = models.DateTimeField(default=timezone.now)


class LetterEvent(models.Model):
    """Live-update log; its id is the reconnect catch-up cursor."""

    letter = models.ForeignKey(Letter, on_delete=models.PROTECT, related_name="events")
    kind = models.CharField(max_length=20)
    actor = models.ForeignKey(User, null=True, on_delete=models.PROTECT, related_name="+")
    data = models.JSONField(default=dict, blank=True)
    at = models.DateTimeField(default=timezone.now)
