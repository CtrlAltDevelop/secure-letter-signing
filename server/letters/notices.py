"""Workspace events and change history for letters v2 features (referrals, tasks, paraphs, numbers, customers).
Event data and history carry ids only, never titles or notes."""
from accounts.models import User
from workspace import events as wevents
from workspace.models import ChangeHistory, Subject

from . import rules
from .models import Letter


def history(subject: Subject | None, actor: User | None, field: str, old, new) -> None:
    if subject is not None:
        ChangeHistory.objects.create(subject=subject, actor=actor, field=field, old=old, new=new)


def announce(letter: Letter, kind: str, actor: User | None, extra_recipients=(), **data) -> None:
    """`letter.<kind>` on the workspace stream to everyone who may see the letter now (minus the actor)."""
    ids = (rules.audience_ids(letter) | set(extra_recipients)) - ({actor.id} if actor else set())
    wevents.emit("letters", f"letter.{kind}", letter.subject, letter.title, actor, ids, letter_id=str(letter.id), **data)
