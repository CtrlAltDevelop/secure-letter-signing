"""User preferences: lazy row, do-not-disturb, personal email verification, background image."""
from django.core import signing
from django.utils import timezone
from ninja.errors import HttpError

from core import filestore

from . import mailer
from .models import User, UserPrefs

EMAIL_SALT = "personal-email"
EMAIL_MAX_AGE = 24 * 3600
BACKGROUND_MAX_BYTES = 2 * 1024 * 1024
IMAGE_SIGNATURES = (("image/png", b"\x89PNG\r\n\x1a\n"), ("image/jpeg", b"\xff\xd8\xff"))


def prefs_of(user: User) -> UserPrefs:
    row, _ = UserPrefs.objects.get_or_create(user=user)
    return row


def in_dnd(user_id: int) -> bool:
    until = UserPrefs.objects.filter(user_id=user_id).values_list("dnd_until", flat=True).first()
    return bool(until and until > timezone.now())


def start_email_verification(user: User, email: str) -> None:
    """Store the unverified address and mail it a token (503 when email is not configured)."""
    if not mailer.email_configured():
        raise HttpError(503, "Email is not configured")
    prefs = prefs_of(user)
    prefs.personal_email, prefs.personal_email_verified = email, False
    prefs.save(update_fields=["personal_email", "personal_email_verified"])
    token = signing.dumps({"u": user.id, "e": email}, salt=EMAIL_SALT)
    mailer.send(email, "Verify your personal email", f"Your verification token:\n\n{token}\n")


def verify_email(user: User, token: str) -> UserPrefs:
    try:
        payload = signing.loads(token, salt=EMAIL_SALT, max_age=EMAIL_MAX_AGE)
    except signing.BadSignature as exc:
        raise HttpError(400, "Invalid or expired token") from exc
    prefs = prefs_of(user)
    if payload.get("u") != user.id or not prefs.personal_email or payload.get("e") != prefs.personal_email:
        raise HttpError(400, "Invalid or expired token")
    prefs.personal_email_verified = True
    prefs.save(update_fields=["personal_email_verified"])
    return prefs


def sniff_image(data: bytes) -> str | None:
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    return next((kind for kind, magic in IMAGE_SIGNATURES if data.startswith(magic)), None)


def set_background(user: User, data: bytes) -> UserPrefs:
    if not data:
        raise HttpError(422, "File is empty")
    if len(data) > BACKGROUND_MAX_BYTES:
        raise HttpError(413, "The image is larger than 2 MB")
    kind = sniff_image(data)
    if kind is None:
        raise HttpError(422, "Only PNG, JPEG and WebP images are allowed")
    prefs = prefs_of(user)
    filestore.save_encrypted(prefs.background, data, f"bg-{timezone.now():%Y%m%d%H%M%S%f}")
    prefs.background_type, prefs.background_active = kind, True
    prefs.save(update_fields=["background", "background_type", "background_active"])
    return prefs


def read_background(user: User) -> tuple[bytes, str]:
    prefs = UserPrefs.objects.filter(user=user, background_active=True).first()
    if prefs is None or not prefs.background:
        raise HttpError(404, "Not found")
    try:
        return filestore.read_decrypted(prefs.background), prefs.background_type
    except filestore.DecryptError as exc:
        raise HttpError(500, "Stored image cannot be decrypted; check DJANGO_DATA_KEY") from exc


def clear_background(user: User) -> None:
    if not UserPrefs.objects.filter(user=user, background_active=True).update(background_active=False):
        raise HttpError(404, "Not found")
