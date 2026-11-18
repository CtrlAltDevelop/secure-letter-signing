"""Notifications: stored in-app, pushed live over the WebSocket, and emailed when SMTP is configured."""
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.db import transaction

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


def notify(users, kind: str, title: str, **data) -> None:
    """Title-only notification for `users` (User objects). Sent after the surrounding transaction commits."""
    users = [u for u in users if u.is_active]
    rows = Notification.objects.bulk_create([Notification(user=u, kind=kind, title=title[:300], data=data) for u in users])
    cs = CompanySettings.load()

    def deliver() -> None:
        for user, row in zip(users, rows):
            push(user.id, {"type": "notification", "id": row.id, "kind": kind, "title": row.title, "data": data})
            if mailer.email_configured(cs):
                mailer.send(user.email, row.title, f"{row.title}\n\nOpen the app to see details.\n")

    transaction.on_commit(deliver)


def managers() -> list[User]:
    return list(User.objects.filter(is_manager=True, is_active=True))
