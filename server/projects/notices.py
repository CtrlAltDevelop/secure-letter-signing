"""Live events and notifications of the projects module. Titles may travel in events; audit rows never carry them."""
from collections.abc import Iterable

from accounts.models import User
from accounts.notify import notify
from workspace.events import emit

from . import rules
from .models import Project

MODULE = "projects"


def emit_project(kind: str, project: Project, actor: User, **data) -> None:
    """Event to every active member except the actor."""
    recipients = rules.audience(project) - {actor.id}
    emit(MODULE, kind, project.subject, project.name, actor, recipients, object_id=str(project.id), **data)


def notify_added(user_ids: Iterable[int], project: Project, actor: User) -> None:
    users = list(User.objects.filter(pk__in=set(user_ids) - {actor.id}, is_active=True))
    if users:
        notify(users, "project.member_added", project.name, module=MODULE, subject_id=str(project.subject_id),
               object_id=str(project.id))
