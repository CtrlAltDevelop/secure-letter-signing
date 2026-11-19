"""Manager side of guests (external collaborators) and of per-user login history. Nothing here deletes anything;
switching a guest off is the existing `POST /manage/users/{id}/active`."""
from datetime import datetime

from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.core.validators import validate_email
from django.db import IntegrityError, transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja import Router, Schema
from ninja.errors import HttpError

from . import guests
from .api_security import LoginEventOut, login_history
from .auth import BearerAuth, require_manager
from .models import User, audit
from .schemas import UserOut

router = Router(tags=["manager"], auth=BearerAuth())


class GuestIn(Schema):
    email: str
    password: str
    full_name: str = ""
    guest_expires_at: datetime | None = None


class GuestPatch(Schema):
    full_name: str | None = None
    guest_expires_at: datetime | None = None
    clear_expiry: bool = False  # true = the guest never expires


def _future(when: datetime | None) -> None:
    if when is not None and when <= timezone.now():
        raise HttpError(422, "The expiry must be in the future")


@router.get("/guests", response=list[UserOut])
def list_guests(request):
    require_manager(request)
    return [UserOut.of(u) for u in User.objects.filter(is_guest=True).prefetch_related("grants").order_by("email")]


@router.post("/guests", response=UserOut)
def create_guest(request, data: GuestIn):
    """Direct creation: the manager hands the password over. For self-signup use an invitation with `guest: true`."""
    manager = require_manager(request)
    email = data.email.strip().lower()
    try:
        validate_email(email)
        validate_password(data.password)
    except ValidationError as exc:
        raise HttpError(422, " ".join(exc.messages)) from exc
    _future(data.guest_expires_at)
    try:
        with transaction.atomic():
            user = guests.create_guest(email, data.password, data.full_name.strip()[:150], data.guest_expires_at)
    except IntegrityError as exc:
        raise HttpError(409, "Email already registered") from exc
    audit(manager, "guest_created", str(user.id))
    return UserOut.of(user)


@router.patch("/guests/{user_id}", response=UserOut)
def update_guest(request, user_id: int, data: GuestPatch):
    manager = require_manager(request)
    guest = get_object_or_404(User, pk=user_id, is_guest=True)
    _future(data.guest_expires_at)
    fields = []
    if data.full_name is not None:
        guest.full_name, fields = data.full_name.strip()[:150], [*fields, "full_name"]
    if data.guest_expires_at is not None or data.clear_expiry:
        guest.guest_expires_at, fields = None if data.clear_expiry else data.guest_expires_at, [*fields, "guest_expires_at"]
    if fields:
        guest.save(update_fields=fields)
        audit(manager, "guest_changed", str(guest.id), fields=fields)
    return UserOut.of(guest)


@router.get("/users/{user_id}/login-history", response=list[LoginEventOut])
def user_login_history(request, user_id: int, limit: int = 50, offset: int = 0):
    require_manager(request)
    return login_history(get_object_or_404(User, pk=user_id), limit, offset)
