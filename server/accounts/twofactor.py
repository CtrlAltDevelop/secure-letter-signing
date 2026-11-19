"""Two-factor login: TOTP secret (encrypted at rest), recovery codes, and the short-lived login challenge."""
import secrets

from django.contrib.auth.hashers import check_password as check_hash
from django.contrib.auth.hashers import make_password as make_hash
from django.core import signing
from django.core.cache import cache
from django.db import transaction
from django.utils import timezone
from ninja.errors import HttpError

from core import cryptoutil

from . import totp
from .models import RecoveryCode, User, audit

CHALLENGE_SALT = "login-2fa"
CHALLENGE_MAX_AGE = 300  # seconds
RECOVERY_COUNT = 10
ISSUER_FALLBACK = "Workplace"


def secret_of(user: User) -> str:
    return cryptoutil.decrypt_bytes(user.totp_secret.encode()).decode() if user.totp_secret else ""


def start_setup(user: User, issuer: str) -> dict:
    """New pending secret (not enabled until a code proves the app has it)."""
    if user.totp_enabled:
        raise HttpError(409, "Two-factor login is already enabled")
    secret = totp.new_secret()
    user.totp_secret = cryptoutil.encrypt_bytes(secret.encode()).decode()
    user.save(update_fields=["totp_secret"])
    return {"secret": secret, "otpauth_uri": totp.otpauth_uri(secret, user.email, issuer or ISSUER_FALLBACK)}


def code_ok(user: User, code: str, *, burn: bool = True) -> bool:
    """True for a valid TOTP code. With `burn` (default) each code works once (the cache add is atomic), so a
    sniffed code cannot be replayed inside its 90 s validity window."""
    secret = secret_of(user)
    if not (secret and totp.verify(secret, code)):
        return False
    return not burn or cache.add(f"totp-used:{user.id}:{code.strip()}", 1, 90)


def _normalize(code: str) -> str:
    return (code or "").strip().lower().replace("-", "").replace(" ", "")


def _issue_recovery_codes(user: User) -> list[str]:
    """Replace every unused code with a fresh batch (old rows are marked used, never deleted)."""
    RecoveryCode.objects.filter(user=user, used_at__isnull=True).update(used_at=timezone.now())
    codes = [secrets.token_hex(5) for _ in range(RECOVERY_COUNT)]
    RecoveryCode.objects.bulk_create([RecoveryCode(user=user, hash=make_hash(c)) for c in codes])
    return [f"{c[:5]}-{c[5:]}" for c in codes]


def recovery_codes_left(user: User) -> int:
    return RecoveryCode.objects.filter(user=user, used_at__isnull=True).count()


@transaction.atomic
def enable(user: User, code: str) -> list[str]:
    if user.totp_enabled:
        raise HttpError(409, "Two-factor login is already enabled")
    if not user.totp_secret:
        raise HttpError(409, "Start the setup first")
    if not code_ok(user, code, burn=False):
        raise HttpError(403, "The code is wrong")
    user.totp_enabled = True
    user.save(update_fields=["totp_enabled"])
    codes = _issue_recovery_codes(user)
    audit(user, "two_factor_enabled", str(user.id))
    return codes


@transaction.atomic
def disable(user: User) -> None:
    user.totp_enabled = False
    user.totp_secret = ""
    user.save(update_fields=["totp_enabled", "totp_secret"])
    RecoveryCode.objects.filter(user=user, used_at__isnull=True).update(used_at=timezone.now())
    audit(user, "two_factor_disabled", str(user.id))


@transaction.atomic
def regenerate(user: User) -> list[str]:
    codes = _issue_recovery_codes(user)
    audit(user, "recovery_codes_regenerated", str(user.id))
    return codes


def use_recovery_code(user: User, code: str) -> bool:
    """One-time: the matching row is claimed with a conditional update, so a replay (or a race) fails."""
    wanted = _normalize(code)
    if len(wanted) != 10:
        return False
    for row in RecoveryCode.objects.filter(user=user, used_at__isnull=True):
        if check_hash(wanted, row.hash):
            return RecoveryCode.objects.filter(pk=row.pk, used_at__isnull=True).update(used_at=timezone.now()) == 1
    return False


def issue_challenge(user: User) -> str:
    return signing.dumps({"u": user.id, "p": user.password[-16:], "n": secrets.token_urlsafe(12)}, salt=CHALLENGE_SALT)


def read_challenge(token: str) -> dict:
    """Payload of a valid, unexpired, unused challenge; 401 otherwise."""
    try:
        payload = signing.loads(token, salt=CHALLENGE_SALT, max_age=CHALLENGE_MAX_AGE)
    except signing.BadSignature as exc:
        raise HttpError(401, "The login challenge is invalid or expired") from exc
    if cache.get(_used_key(payload["n"])):
        raise HttpError(401, "The login challenge was already used")
    return payload


def _used_key(nonce: str) -> str:
    return f"2fa-used:{nonce}"


def burn_challenge(payload: dict) -> None:
    """Single use: `cache.add` is atomic, so two concurrent completions cannot both pass."""
    if not cache.add(_used_key(payload["n"]), 1, CHALLENGE_MAX_AGE + 60):
        raise HttpError(401, "The login challenge was already used")
