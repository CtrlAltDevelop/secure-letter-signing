"""Append-only login attempt log. Failures are stored against the matching user when the email exists."""
from django.utils import timezone

from . import ratelimit
from .models import LoginEvent, User


def record(request, *, email: str, user: User | None, success: bool, device_name: str = "", reason: str = "") -> None:
    LoginEvent.objects.create(
        user=user, email_tried=email[:254], at=timezone.now(), ip=ratelimit.client_ip(request),
        user_agent=request.META.get("HTTP_USER_AGENT", "")[:300], success=success,
        device_name=device_name[:100], reason=reason[:40],
    )
