"""Notifications: stored in-app, pushed live over the WebSocket, and emailed when SMTP is configured."""
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.db import transaction
from django.utils import timezone

import logging

from . import mailer
from .models import CompanySettings, Notification, User


logger = logging.getLogger(__name__)


def user_group(user_id: int) -> str:
    return f"user_{user_id}"


def session_group(session_id) -> str:
    return f"session_{session_id}"


def push_session(session_id, event: dict) -> None:
    """Live event to the connection(s) of one session only (not replayed; the app re-fetches on connect)."""
    layer = get_channel_layer()
    if layer is None:
        return
    try:
        async_to_sync(layer.group_send)(session_group(session_id), {"type": "event", "event": event})
    except Exception:  # noqa: BLE001  same reasoning as push()
        logger.exception("Live push to session %s failed", session_id)


def push(user_id: int, event: dict) -> None:
    """Live event to every open connection of this user. No-op failure must never break the request."""
    layer = get_channel_layer()
    if layer is None:
        return
    try:
        async_to_sync(layer.group_send)(user_group(user_id), {"type": "event", "event": event})
    except Exception:  # noqa: BLE001  the commit already happened; a dead Redis must not turn it into a 500
        logger.exception("Live push to user %s failed", user_id)


# Kinds also mailed to a verified personal email (everything is mailed to the account email as before).
IMPORTANT_KINDS = frozenset({
    "task.assigned", "task.approval_needed", "meeting.invited", "letter_published", "letter_rejected",
    "letter_referral", "referral_response", "sign_request", "mention", "reminder", "work.transferred",
    "lead.assigned", "task.removal_requested", "gantt.task_ready"})


BODY = "{}\n\nOpen the app to see details.\n"


def _prefs_by_user(users) -> dict:
    from .models import UserPrefs

    return {p.user_id: p for p in UserPrefs.objects.filter(user__in=users)}


def notify(users, kind: str, title: str, **data) -> None:
    """Title-only notification for `users` (User objects). Stored at once; pushed and emailed after the surrounding
    transaction commits, unless the user is in do-not-disturb at that moment (the row is still stored)."""
    users = [u for u in users if u.is_active]
    rows = Notification.objects.bulk_create([Notification(user=u, kind=kind, title=title[:300], data=data) for u in users])
    cs = CompanySettings.load()
    prefs = _prefs_by_user(users)

    def deliver() -> None:
        now = timezone.now()
        for user, row in zip(users, rows):
            own = prefs.get(user.id)
            if own and own.dnd_until and own.dnd_until > now:
                continue
            push(user.id, {"type": "notification", "id": row.id, "kind": kind, "title": row.title, "data": data})
            if not mailer.email_configured(cs):
                continue
            mailer.send(user.email, row.title, BODY.format(row.title))
            if own and own.personal_email_verified and own.personal_email and kind in IMPORTANT_KINDS:
                mailer.send(own.personal_email, row.title, BODY.format(row.title))

    transaction.on_commit(deliver)


def managers() -> list[User]:
    return list(User.objects.filter(is_manager=True, is_active=True))
