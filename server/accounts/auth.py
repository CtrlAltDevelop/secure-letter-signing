import hashlib
import secrets
from datetime import timedelta

from django.core import signing
from django.utils import timezone
from ninja.errors import HttpError
from ninja.security import HttpBearer

from workspace import registry

from . import guests
from .models import Session, User

ACCESS_MAX_AGE = 600  # seconds; revocation is also checked in the DB on every request
TOUCH_EVERY = timedelta(seconds=60)


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def new_refresh_token() -> str:
    return secrets.token_urlsafe(32)


def issue_access(session: Session) -> str:
    return signing.dumps({"s": str(session.id)}, salt="access")


class BearerAuth(HttpBearer):
    """request.auth is the live Session; use `user_of(request)` for the user."""

    def authenticate(self, request, token: str):
        try:
            data = signing.loads(token, salt="access", max_age=ACCESS_MAX_AGE)
        except signing.BadSignature:
            return None
        session = (
            Session.objects.select_related("user")
            .filter(id=data["s"], revoked_at__isnull=True, user__is_active=True)
            .first()
        )
        if session is None or guests.is_expired(session.user):
            return None
        registry.set_current_user(session.user)
        if timezone.now() - session.last_active > TOUCH_EVERY:
            Session.objects.filter(pk=session.pk).update(last_active=timezone.now())
        return session


def user_of(request) -> User:
    return request.auth.user


def require_grant(request, code: str) -> User:
    user = user_of(request)
    if not user.has_grant(code):
        raise HttpError(403, "Permission denied")
    return user


def require_manager(request) -> User:
    user = user_of(request)
    if not user.is_manager:
        raise HttpError(403, "Manager only")
    return user
