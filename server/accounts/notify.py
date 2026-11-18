"""Notifications: stored in-app, pushed live over the WebSocket, and emailed when SMTP is configured."""
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.db import transaction

from . import mailer
from .models import CompanySettings, Notification, User


def user_group(user_id: int) -> str:
    return f"user_{user_id}"


def push(user_id: int, event: dict) -> None:
    """Live event to every open connection of this user. No-op failure must never break the request."""
    layer = get_channel_layer()
    if layer is not None:
        async_to_sync(layer.group_send)(user_group(user_id), {"type": "event", "event": event})


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
