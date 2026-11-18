from datetime import datetime
from uuid import UUID

from django.contrib.auth.hashers import check_password as check_hash
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja import Router, Schema
from ninja.errors import HttpError

from . import ratelimit
from .api_auth import Detail, check_password
from .auth import BearerAuth, user_of
from .models import CompanySettings, Notification, Session, audit
from .schemas import SessionOut, UserOut

router = Router(tags=["me"], auth=BearerAuth())


class ProfileIn(Schema):
    full_name: str | None = None
    title: str | None = None


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
        setattr(user, field, value.strip()[:user._meta.get_field(field).max_length])
    user.save(update_fields=list(changes))
    return UserOut.of(user)


@router.get("/sessions", response=list[SessionOut])
def sessions(request):
    rows = Session.objects.filter(user=user_of(request), revoked_at__isnull=True).order_by("-last_active")
    return [
        SessionOut(
            id=s.id, device_name=s.device_name, platform=s.platform, ip=s.ip,
            created_at=s.created_at, last_active=s.last_active, current=s.id == request.auth.id,
        )
        for s in rows
    ]


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
