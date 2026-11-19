"""Caller-side security: two-step login (TOTP) setup, login history, closing other sessions."""
from datetime import datetime

from django.contrib.auth.hashers import check_password as check_hash
from django.utils import timezone
from ninja import Router, Schema
from ninja.errors import HttpError

from . import ratelimit, twofactor
from .api_auth import Detail
from .auth import BearerAuth, user_of
from .models import CompanySettings, LoginEvent, Session, User, audit

router = Router(tags=["security"], auth=BearerAuth())
SCOPE = "me-2fa"
MAX_PAGE = 200


class TwoFactorOut(Schema):
    enabled: bool
    setup_pending: bool  # a secret was issued but not confirmed yet
    recovery_codes_left: int
    required: bool  # the company requires 2FA


class TwoFactorSetupOut(Schema):
    secret: str
    otpauth_uri: str


class CodeIn(Schema):
    code: str


class ProofIn(Schema):
    password: str
    code: str | None = None
    recovery_code: str | None = None


class RecoveryCodesOut(Schema):
    recovery_codes: list[str]


class LoginEventOut(Schema):
    id: int
    at: datetime
    ip: str | None
    user_agent: str
    device_name: str
    success: bool
    reason: str  # empty on success; bad_password, bad_code, locked, guest_expired

    @staticmethod
    def of(e: LoginEvent) -> "LoginEventOut":
        return LoginEventOut(id=e.id, at=e.at, ip=e.ip, user_agent=e.user_agent, device_name=e.device_name,
                             success=e.success, reason=e.reason)


def login_history(user: User, limit: int, offset: int) -> list[LoginEventOut]:
    rows = LoginEvent.objects.filter(user=user).order_by("-at", "-id")
    start = max(offset, 0)
    return [LoginEventOut.of(e) for e in rows[start: start + max(min(limit, MAX_PAGE), 0)]]


def _status(user: User) -> TwoFactorOut:
    return TwoFactorOut(enabled=user.totp_enabled, setup_pending=bool(user.totp_secret) and not user.totp_enabled,
                        recovery_codes_left=twofactor.recovery_codes_left(user) if user.totp_enabled else 0,
                        required=CompanySettings.load().require_2fa)


def _require_proof(user: User, data: ProofIn) -> None:
    """Password plus a current code or a recovery code, behind the same lockout as the other password checks."""
    ratelimit.check(SCOPE, str(user.id))
    if not user.totp_enabled:
        raise HttpError(409, "Two-factor login is not enabled")
    if not data.code and not data.recovery_code:
        raise HttpError(422, "A code or a recovery code is required")
    ok = check_hash(data.password, user.password) and (
        twofactor.use_recovery_code(user, data.recovery_code) if data.recovery_code
        else twofactor.code_ok(user, data.code or ""))
    if not ok:
        ratelimit.fail(SCOPE, str(user.id))
        raise HttpError(403, "Password or code is wrong")
    ratelimit.reset(SCOPE, str(user.id))


@router.get("/2fa", response=TwoFactorOut)
def two_factor_status(request):
    return _status(user_of(request))


@router.post("/2fa", response=TwoFactorSetupOut)
def two_factor_setup(request):
    """New pending secret and the otpauth:// URI for the authenticator app. Not active until /2fa/confirm."""
    user = user_of(request)
    ratelimit.hit("me-2fa-setup", str(user.id), 10, 3600)
    return twofactor.start_setup(user, CompanySettings.load().letterhead.get("name", ""))


@router.post("/2fa/confirm", response=RecoveryCodesOut)
def two_factor_confirm(request, data: CodeIn):
    """Turns 2FA on once a code from the app is right; returns the one-time recovery codes (shown only now)."""
    user = user_of(request)
    ratelimit.check(SCOPE, str(user.id))
    try:
        codes = twofactor.enable(user, data.code)
    except HttpError as exc:
        if exc.status_code == 403:
            ratelimit.fail(SCOPE, str(user.id))
        raise
    ratelimit.reset(SCOPE, str(user.id))
    return {"recovery_codes": codes}


@router.post("/2fa/disable", response=Detail)
def two_factor_disable(request, data: ProofIn):
    user = user_of(request)
    _require_proof(user, data)
    twofactor.disable(user)
    return {"detail": "Two-factor login turned off"}


@router.post("/2fa/recovery-codes", response=RecoveryCodesOut)
def two_factor_new_recovery_codes(request, data: ProofIn):
    """Replaces every unused recovery code with a fresh batch."""
    user = user_of(request)
    _require_proof(user, data)
    return {"recovery_codes": twofactor.regenerate(user)}


@router.get("/login-history", response=list[LoginEventOut])
def my_login_history(request, limit: int = 50, offset: int = 0):
    """The caller's own sign-ins and failed attempts, newest first. Nobody else's."""
    return login_history(user_of(request), limit, offset)


@router.post("/sessions/revoke-others", response=dict)
def revoke_other_sessions(request):
    user = user_of(request)
    n = Session.objects.filter(user=user, revoked_at__isnull=True).exclude(pk=request.auth.pk).update(
        revoked_at=timezone.now())
    audit(user, "sessions_revoked_others", str(user.id), count=n)
    return {"detail": "Other sessions closed", "revoked": n}
