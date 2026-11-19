"""Live events and notifications of the tasks module. Titles may travel in events; audit rows never carry them."""
from collections.abc import Iterable

from accounts.models import User
from accounts.notify import notify
from workspace.events import emit

from . import rules
from .models import Task

MODULE = "tasks"


def emit_task(kind: str, task: Task, actor: User, extra_recipients: Iterable[int] = (), **data) -> None:
    """Event to everyone who can see the task (and `extra_recipients`) except the actor."""
    recipients = (rules.audience(task) | set(extra_recipients)) - {actor.id}
    emit(MODULE, kind, task.subject, task.title, actor, recipients, object_id=str(task.id), **data)


def notify_users(user_ids: Iterable[int], kind: str, task: Task, actor: User) -> None:
    ids = set(user_ids) - {actor.id}
    users = list(User.objects.filter(pk__in=ids, is_active=True))
    if users:
        notify(users, kind, task.title, module=MODULE, subject_id=str(task.subject_id), object_id=str(task.id))
