from uuid import UUID

from django.contrib.auth.hashers import check_password as check_hash
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja import Router, Schema
from ninja.errors import HttpError

from .api_auth import Detail, check_password
from .auth import BearerAuth, user_of
from .models import Session, audit
from .schemas import SessionOut, UserOut

router = Router(tags=["me"], auth=BearerAuth())


class ProfileIn(Schema):
    full_name: str | None = None
    title: str | None = None
    department: str | None = None


class PasswordIn(Schema):
    current_password: str
    new_password: str


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
    if not check_hash(data.current_password, user.password):
        raise HttpError(403, "Current password is wrong")
    check_password(data.new_password, user)
    user.set_password(data.new_password)
    user.save(update_fields=["password"])
    Session.objects.filter(user=user, revoked_at__isnull=True).exclude(pk=request.auth.pk).update(
        revoked_at=timezone.now()
    )
    audit(user, "password_changed", user.email)
    return {"detail": "Password changed"}
