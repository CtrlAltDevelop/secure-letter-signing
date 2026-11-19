import uuid

from django.conf import settings
from django.db import models
from django.db.models import Q
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
    # Workspace anchor (labels, comments, files, seen-by, reminders). Null only until the data migration has run.
    subject = models.OneToOneField("workspace.Subject", null=True, blank=True, on_delete=models.PROTECT,
                                   related_name="letter")


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


class Referral(models.Model):
    """A participant refers a letter to a colleague for a decision; the referee may read the letter (never sign)."""

    PENDING, DONE, DECLINED = "pending", "done", "declined"

    letter = models.ForeignKey(Letter, on_delete=models.PROTECT, related_name="referrals")
    from_user = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    to_user = models.ForeignKey(User, on_delete=models.PROTECT, related_name="referrals_received")
    note = models.JSONField(default=dict, blank=True)  # encrypted text box (workspace.textbox)
    status = models.CharField(max_length=8, default=PENDING)
    response_note = models.JSONField(default=dict, blank=True)  # encrypted text box
    created_at = models.DateTimeField(default=timezone.now)
    responded_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        indexes = [models.Index(fields=["to_user", "status"], name="referral_to_status")]


class LetterTaskLink(models.Model):
    letter = models.ForeignKey(Letter, on_delete=models.PROTECT, related_name="task_links")
    task = models.ForeignKey("tasks.Task", on_delete=models.PROTECT, related_name="+")
    added_by = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    added_at = models.DateTimeField(default=timezone.now)
    active = models.BooleanField(default=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["letter", "task"], name="one_link_per_letter_task")]


class ArchiveMark(models.Model):
    """Per-user archive flag of a letter (toggle = `active`)."""

    letter = models.ForeignKey(Letter, on_delete=models.PROTECT, related_name="archive_marks")
    user = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    active = models.BooleanField(default=True)
    at = models.DateTimeField(default=timezone.now)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["letter", "user"], name="one_archive_mark_per_user")]


class Paraph(models.Model):
    """Initialling of a letter. Immutable (DB trigger); sealed exactly like a signature."""

    letter = models.ForeignKey(Letter, on_delete=models.PROTECT, related_name="paraphs")
    user = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    method = models.CharField(max_length=10, choices=[("pin", "pin"), ("biometric", "biometric")])
    payload = models.JSONField()
    seal = models.CharField(max_length=128)
    nonce = models.CharField(max_length=64, unique=True)
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["letter", "user"], name="one_paraph_per_user")]


class NumberSequence(models.Model):
    """Last number handed out per kind and Jalali year; always updated under `select_for_update`."""

    IN, OUT, INTERNAL = "in", "out", "internal"

    kind = models.CharField(max_length=8, choices=[(k, k) for k in (IN, OUT, INTERNAL)])
    jalali_year = models.PositiveSmallIntegerField()
    last = models.PositiveIntegerField(default=0)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["kind", "jalali_year"], name="one_sequence_per_kind_year")]


class SecretariatEntry(models.Model):
    """Secretariat (dabirkhaneh) register row: an incoming external letter or an outgoing number for a letter."""

    IN, OUT = "in", "out"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    subject = models.OneToOneField("workspace.Subject", on_delete=models.PROTECT, related_name="secretariat_entry")
    direction = models.CharField(max_length=3, choices=[(IN, IN), (OUT, OUT)])
    jalali_year = models.PositiveSmallIntegerField()
    seq = models.PositiveIntegerField()
    number = models.CharField(max_length=20)  # "{jalali_year}/{seq:04d}"
    registered_at = models.DateTimeField(default=timezone.now)
    registered_by = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    title = models.CharField(max_length=200)
    party_name = models.CharField(max_length=200, blank=True)
    party_ref = models.CharField(max_length=100, blank=True)
    letter = models.ForeignKey(Letter, null=True, blank=True, on_delete=models.PROTECT,
                               related_name="secretariat_entries")
    summary = models.JSONField(default=dict, blank=True)  # encrypted text box
    active = models.BooleanField(default=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["direction", "jalali_year", "seq"], name="one_number_per_sequence"),
            models.UniqueConstraint(fields=["letter"], condition=Q(letter__isnull=False),
                                    name="one_number_per_letter"),
        ]


class CustomerLink(models.Model):
    """Links a subject (letter or secretariat entry) to a customer file. Customer files do not exist yet:
    `customer_ref` is a bare UUID today and becomes a foreign key later."""

    subject = models.ForeignKey("workspace.Subject", on_delete=models.PROTECT, related_name="customer_links")
    customer_ref = models.UUIDField(null=True, blank=True)
    added_by = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    at = models.DateTimeField(default=timezone.now)
    active = models.BooleanField(default=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["subject", "customer_ref"], name="one_link_per_customer")]
