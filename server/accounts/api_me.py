from datetime import datetime
from uuid import UUID

from django.contrib.auth.hashers import check_password as check_hash
from django.contrib.auth.hashers import make_password as make_hash
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja import Router, Schema
from ninja.errors import HttpError
from pydantic import Field

from . import ratelimit
from .api_auth import Detail, check_password
from .api_security import router as security_router
from .auth import BearerAuth, user_of
from .models import CompanySettings, Notification, Session, audit
from .schemas import SessionOut, UserOut

router = Router(tags=["me"], auth=BearerAuth())


class ProfileIn(Schema):
    full_name: str | None = None
    title: str | None = None
    phone: str | None = Field(None, pattern=r"^(\+?[0-9]{8,15})?$")  # empty clears it
    status_text: str | None = Field(None, max_length=80)  # empty clears it


class PasswordIn(Schema):
    current_password: str
    new_password: str


@router.get("/letterhead")
def letterhead(request):
    """Printed header/footer the manager configured; any signed-in user may read it."""
    user_of(request)
    return CompanySettings.load().letterhead


@router.get("", response=UserOut)
def me(request):
    return UserOut.of(user_of(request))


@router.patch("", response=UserOut)
def update_profile(request, data: ProfileIn):
    user = user_of(request)
    changes = data.dict(exclude_none=True)
    for field, value in changes.items():
        value = value.strip()[:user._meta.get_field(field).max_length]
        setattr(user, field, (value or None) if field == "phone" else value)
    user.save(update_fields=list(changes))
    return UserOut.of(user)


def _session_out(s: Session, *, current_id) -> SessionOut:
    return SessionOut(
        id=s.id, device_name=s.device_name, platform=s.platform, ip=s.ip, created_at=s.created_at,
        last_active=s.last_active, current=s.id == current_id, biometric=s.biometric,
    )


@router.get("/sessions", response=list[SessionOut])
def sessions(request):
    rows = Session.objects.filter(user=user_of(request), revoked_at__isnull=True).order_by("-last_active")
    return [_session_out(s, current_id=request.auth.id) for s in rows]


class SessionPatchIn(Schema):
    biometric: bool
    pin: str | None = None


@router.patch("/sessions/current", response=SessionOut)
def update_current_session(request, data: SessionPatchIn):
    """Enrol (needs the signing PIN, checked like signing) or drop biometrics for this session."""
    from letters import signing  # local import: letters depends on accounts

    session = request.auth
    if data.biometric and not session.biometric:
        if not data.pin:
            raise HttpError(422, "The signing PIN is required to turn biometrics on")
        signing.check_pin(user_of(request), data.pin, session)
        audit(session.user, "session_biometric_enabled", str(session.id), device=session.device_name)
    if data.biometric != session.biometric:
        session.biometric = data.biometric
        session.save(update_fields=["biometric"])
    return _session_out(session, current_id=session.id)


@router.post("/sessions/{session_id}/revoke", response=Detail)
def revoke_session(request, session_id: UUID):
    session = get_object_or_404(Session, id=session_id, user=user_of(request), revoked_at__isnull=True)
    session.revoked_at = timezone.now()
    session.save(update_fields=["revoked_at"])
    audit(session.user, "session_revoked", str(session.id))
    return {"detail": "Session revoked"}


@router.post("/password", response=Detail)
def change_password(request, data: PasswordIn):
    user = user_of(request)
    ratelimit.check("me-password", str(user.id))
    if not check_hash(data.current_password, user.password):
        ratelimit.fail("me-password", str(user.id))
        raise HttpError(403, "Current password is wrong")
    ratelimit.reset("me-password", str(user.id))
    check_password(data.new_password, user)
    user.set_password(data.new_password)
    user.save(update_fields=["password"])
    Session.objects.filter(user=user, revoked_at__isnull=True).exclude(pk=request.auth.pk).update(
        revoked_at=timezone.now()
    )
    audit(user, "password_changed", user.email)
    return {"detail": "Password changed"}


class SigningPinIn(Schema):
    pin: str = Field(pattern=r"^[0-9]{6}$")
    password: str


@router.put("/signing-pin", response=Detail)
def set_signing_pin(request, data: SigningPinIn):
    """Set or change the 6-digit signing PIN. Needs the login password (same lockout as /me/password)."""
    user = user_of(request)
    ratelimit.check("me-password", str(user.id))
    if not check_hash(data.password, user.password):
        ratelimit.fail("me-password", str(user.id))
        raise HttpError(403, "Password is wrong")
    ratelimit.reset("me-password", str(user.id))
    user.signing_pin_hash = make_hash(data.pin)
    user.save(update_fields=["signing_pin_hash"])
    ratelimit.reset("sign-pin", str(user.id))
    audit(user, "signing_pin_set", user.email)
    return {"detail": "Signing PIN saved"}


class NotificationOut(Schema):
    id: int
    kind: str
    title: str
    data: dict
    at: datetime
    read: bool


@router.get("/notifications", response=list[NotificationOut])
def notifications(request, after: int = 0, limit: int = 100):
    """In-app notifications (the fallback when email is not configured); title only."""
    rows = Notification.objects.filter(user=user_of(request), id__gt=after).order_by("id")[: min(limit, 200)]
    return [NotificationOut(id=n.id, kind=n.kind, title=n.title, data=n.data, at=n.at, read=n.read_at is not None)
            for n in rows]


@router.post("/notifications/read", response=Detail)
def mark_notifications_read(request):
    Notification.objects.filter(user=user_of(request), read_at__isnull=True).update(read_at=timezone.now())
    return {"detail": "ok"}


router.add_router("", security_router)
