from django.db import transaction

from accounts.models import User
from accounts.notify import push

from .models import Letter, LetterEvent
from .rules import audience_ids


def event_payload(ev: LetterEvent, letter: Letter) -> dict:
    return {
        "type": "letter", "event_id": ev.id, "letter_id": str(letter.id), "kind": ev.kind, "title": letter.title,
        "status": letter.status, "actor_id": ev.actor_id, "data": ev.data, "at": ev.at.isoformat(),
    }


def emit(letter: Letter, kind: str, actor: User | None, **data) -> LetterEvent:
    """Record the event and push it live to the letter's audience once the transaction commits."""
    ev = LetterEvent.objects.create(letter=letter, kind=kind, actor=actor, data=data)
    payload, ids = event_payload(ev, letter), audience_ids(letter)
    transaction.on_commit(lambda: [push(uid, payload) for uid in ids])
    return ev
