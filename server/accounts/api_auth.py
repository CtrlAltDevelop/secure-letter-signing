from datetime import timedelta

from django.contrib.auth import authenticate
from django.contrib.auth.password_validation import validate_password
from django.core import signing
from django.core.exceptions import ValidationError
from django.core.validators import validate_email
from django.db import IntegrityError, transaction
from django.db.models import F, Q
from django.utils import timezone
from ninja import Router, Schema, Status
from ninja.errors import HttpError
from ninja.throttling import AnonRateThrottle

from . import mailer, ratelimit
from .auth import BearerAuth, hash_token, issue_access, new_refresh_token
from .models import BASE_PERMISSION, CompanySettings, InviteCode, Permission, RetiredRefresh, Session, User, audit
from .schemas import TokenOut, UserOut

router = Router(tags=["auth"])
throttle = [AnonRateThrottle("20/m")]
VERIFY_MAX_AGE = 3 * 24 * 3600
RESET_MAX_AGE = 24 * 3600
REFRESH_GRACE = timedelta(seconds=10)


class SignupIn(Schema):
    email: str
    password: str
    full_name: str = ""
    invite_code: str | None = None


class LoginIn(Schema):
    email: str
    password: str
    device_name: str = ""
    platform: str = ""


class RefreshIn(Schema):
    refresh: str


class TokenIn(Schema):
    token: str


class ResetRequestIn(Schema):
    email: str


class ResetConfirmIn(Schema):
    token: str
    new_password: str


class Detail(Schema):
    detail: str


def check_password(password: str, user: User | None = None) -> None:
    try:
        validate_password(password, user)
    except ValidationError as exc:
        raise HttpError(422, " ".join(exc.messages)) from exc


def _create_user(email: str, password: str, full_name: str, *, active: bool) -> User:
    user = User.objects.create_user(email, password, full_name=full_name, is_active=active)
    user.grants.add(Permission.objects.get(code=BASE_PERMISSION))
    return user


def _create_or_409(email: str, data, *, active: bool) -> User:
    try:
        with transaction.atomic():  # a concurrent signup for the same email loses here, not with a 500
            return _create_user(email, data.password, data.full_name, active=active)
    except IntegrityError as exc:
        raise HttpError(409, "Email already registered") from exc


@router.post("/signup", auth=None, throttle=throttle, response={201: Detail, 202: Detail})
@transaction.atomic
def signup(request, data: SignupIn):
    email = data.email.strip().lower()
    try:
        validate_email(email)
    except ValidationError as exc:
        raise HttpError(422, "Invalid email") from exc
    if User.objects.filter(email=email).exists():
        raise HttpError(409, "Email already registered")
    check_password(data.password)
    cs = CompanySettings.load()

    if data.invite_code:
        invite = InviteCode.objects.select_for_update().filter(code=data.invite_code, active=True).first()
        usable = (
            cs.signup_invite_enabled and invite is not None
            and (invite.max_uses is None or invite.uses < invite.max_uses)
            and (invite.expires_at is None or invite.expires_at > timezone.now())
        )
        if not usable:
            raise HttpError(403, "Invalid or expired invitation code")
        user = _create_or_409(email, data, active=True)
        # Atomic bump: select_for_update is a no-op on SQLite.
        if not InviteCode.objects.filter(Q(max_uses__isnull=True) | Q(uses__lt=F("max_uses")), pk=invite.pk).update(
            uses=F("uses") + 1
        ):
            raise HttpError(403, "Invalid or expired invitation code")
        user.grants.add(*invite.grants.all())
        if invite.department_id and invite.department.active:
            user.department = invite.department
            user.save(update_fields=["department"])
        audit(user, "signup_invite", email, invite=invite.id)
        return Status(201, {"detail": "Registered"})

    domain = email.rsplit("@", 1)[1]
    if not (cs.signup_domain_enabled and cs.allowed_domain and domain == cs.allowed_domain.lower()):
        raise HttpError(403, "Signup is not available for this email")
    if not mailer.email_configured(cs):
        raise HttpError(503, "Email is not configured; ask the manager for an invitation code")
    user = _create_or_409(email, data, active=False)
    token = signing.dumps({"u": user.id}, salt="verify-email")
    if not mailer.send(email, "Verify your email", f"Your verification token:\n\n{token}\n"):
        raise HttpError(503, "Could not send the verification email")  # rolls the signup back
    audit(user, "signup_domain", email)
    return Status(202, {"detail": "Check your email to verify the account"})


@router.post("/verify-email", auth=None, throttle=throttle, response=Detail)
def verify_email(request, data: TokenIn):
    try:
        uid = signing.loads(data.token, salt="verify-email", max_age=VERIFY_MAX_AGE)["u"]
    except signing.BadSignature as exc:
        raise HttpError(400, "Invalid or expired token") from exc
    # Only unverified accounts: a manager-deactivated user must not reactivate themselves with an old token.
    User.objects.filter(pk=uid, email_verified=False).update(is_active=True, email_verified=True)
    return {"detail": "Email verified"}


@router.post("/login", auth=None, throttle=throttle, response=TokenOut)
def login(request, data: LoginIn):
    email = data.email.strip().lower()
    ratelimit.check("login", email)
    user = authenticate(request, username=email, password=data.password)
    if user is None:
        ratelimit.fail("login", email)
        raise HttpError(401, "Invalid email or password")
    ratelimit.reset("login", email)
    refresh = new_refresh_token()
    session = Session.objects.create(
        user=user, refresh_hash=hash_token(refresh), device_name=data.device_name[:100],
        platform=data.platform[:30], ip=ratelimit.client_ip(request),
        user_agent=request.META.get("HTTP_USER_AGENT", "")[:300],
    )
    audit(user, "login", str(session.id), device=session.device_name)
    return TokenOut(access=issue_access(session), refresh=refresh, session_id=session.id, user=UserOut.of(user))


def _find_refreshable(presented: str):
    """Locked session this refresh token may rotate, or None. Revokes the session on reuse of a retired token."""
    now = timezone.now()
    session = (
        Session.objects.select_for_update().select_related("user")
        .filter(refresh_hash=presented, revoked_at__isnull=True).first()
    )
    if session:
        return session, False
    retired = RetiredRefresh.objects.filter(token_hash=presented).values_list("session_id", flat=True).first()
    if retired is None:
        return None, False
    session = Session.objects.select_for_update().select_related("user").get(pk=retired)
    if session.revoked_at is not None:
        return None, False
    # The client may have lost our response: its immediate predecessor is honoured for a few seconds.
    if session.prev_refresh_hash == presented and now - session.rotated_at < REFRESH_GRACE:
        return session, False
    session.revoked_at = now
    session.save(update_fields=["revoked_at"])
    return None, True


@router.post("/refresh", auth=None, throttle=throttle, response=TokenOut)
def refresh(request, data: RefreshIn):
    presented = hash_token(data.refresh)
    reuse_detected = False
    new_refresh = new_refresh_token()
    with transaction.atomic():
        session, reuse_detected = _find_refreshable(presented)
        if session is not None and session.user.is_active:
            now = timezone.now()
            RetiredRefresh.objects.get_or_create(token_hash=session.refresh_hash, defaults={"session": session})
            if session.refresh_hash == presented:  # normal rotation (not a grace-window retry)
                session.prev_refresh_hash = presented
                session.rotated_at = now
            session.refresh_hash = hash_token(new_refresh)
            session.last_active = now
            session.save(update_fields=["prev_refresh_hash", "rotated_at", "refresh_hash", "last_active"])
        else:
            session = None
    if session is None:
        if reuse_detected:
            audit(None, "refresh_reuse_detected")
        raise HttpError(401, "Invalid refresh token")
    return TokenOut(
        access=issue_access(session), refresh=new_refresh, session_id=session.id, user=UserOut.of(session.user)
    )


@router.post("/logout", auth=BearerAuth(), response=Detail)
def logout(request):
    Session.objects.filter(pk=request.auth.pk).update(revoked_at=timezone.now())
    return {"detail": "Logged out"}


@router.post("/password-reset/request", auth=None, throttle=throttle, response=Detail)
def password_reset_request(request, data: ResetRequestIn):
    """Always answers the same, so it does not reveal which emails exist."""
    email = data.email.strip().lower()
    ratelimit.check("reset", email)  # also caps mail sent to one address
    ratelimit.fail("reset", email)
    user = User.objects.filter(email=email, is_active=True).first()
    if user:
        token = signing.dumps({"u": user.id, "p": user.password[-16:]}, salt="password-reset")
        mailer.send(user.email, "Reset your password", f"Your password reset token:\n\n{token}\n")
    return {"detail": "If the account exists, an email was sent"}


@router.post("/password-reset/confirm", auth=None, throttle=throttle, response=Detail)
def password_reset_confirm(request, data: ResetConfirmIn):
    try:
        payload = signing.loads(data.token, salt="password-reset", max_age=RESET_MAX_AGE)
    except signing.BadSignature as exc:
        raise HttpError(400, "Invalid or expired token") from exc
    user = User.objects.filter(pk=payload["u"], is_active=True).first()
    if user is None or user.password[-16:] != payload["p"]:  # single use: changes with the password
        raise HttpError(400, "Invalid or expired token")
    check_password(data.new_password, user)
    user.set_password(data.new_password)
    user.save(update_fields=["password"])
    Session.objects.filter(user=user, revoked_at__isnull=True).update(revoked_at=timezone.now())
    audit(user, "password_reset", user.email)  # login password only; keys are untouched
    return {"detail": "Password changed"}
