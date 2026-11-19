"""Workspace live stream ("stream": "w"): events are stored with their recipients and pushed on commit."""
from django.db import transaction

from accounts.models import User
from accounts.notify import push

from .models import Event, EventRecipient, Subject

REPLAY_MAX = 500


def frame(ev: Event) -> dict:
    return {
        "type": "ws", "stream": "w", "event_id": ev.id, "module": ev.module, "kind": ev.kind,
        "subject_id": str(ev.subject_id) if ev.subject_id else None, "title": ev.title, "actor_id": ev.actor_id,
        "data": ev.data, "at": ev.at.isoformat(),
    }


def emit(module: str, kind: str, subject: Subject | None, title: str, actor: User | None,
         recipient_ids, **data) -> Event:
    """Write the event and its recipients now; push it live to those users once the transaction commits."""
    ids = sorted(User.objects.filter(pk__in=set(recipient_ids), is_active=True).values_list("pk", flat=True))
    ev = Event.objects.create(module=module, kind=kind, subject=subject, title=title[:300], actor=actor, data=data)
    EventRecipient.objects.bulk_create([EventRecipient(event=ev, user_id=uid) for uid in ids])
    payload = frame(ev)
    transaction.on_commit(lambda: [push(uid, payload) for uid in ids])
    return ev


def replay_events(user: User, after: int, limit: int = REPLAY_MAX) -> list[dict]:
    """The caller's own events with id > after, oldest first."""
    limit = max(min(limit, REPLAY_MAX), 0)
    rows = Event.objects.filter(id__gt=after, recipients__user=user).order_by("id")[:limit]
    return [frame(ev) for ev in rows]
