"""Live events and notifications of the meetings module. Titles may travel in events; audit rows never carry them."""
from collections.abc import Iterable

from accounts.models import User
from accounts.notify import notify
from workspace.events import emit

from . import rules
from .models import Meeting

MODULE = "meetings"


def emit_meeting(kind: str, meeting: Meeting, actor: User, **data) -> None:
    recipients = rules.audience(meeting) - {actor.id}
    emit(MODULE, kind, meeting.subject, meeting.title, actor, recipients, object_id=str(meeting.id), **data)


def notify_users(user_ids: Iterable[int], kind: str, meeting: Meeting, actor: User) -> None:
    users = list(User.objects.filter(pk__in=set(user_ids) - {actor.id}, is_active=True))
    if users:
        notify(users, kind, meeting.title, module=MODULE, subject_id=str(meeting.subject_id),
               object_id=str(meeting.id))
