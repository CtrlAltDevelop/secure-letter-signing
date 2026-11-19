"""Registration of the tasks module in the workspace registry."""
from typing import Any

from accounts.models import User
from workspace.models import Subject
from workspace.registry import ModuleSpec

from . import rules, search, service, transfer
from .models import Task


def resolve(subject: Subject) -> Task | None:
    return Task.objects.select_related("subject").filter(subject=subject).first()


def can(user: User, task: Any, action: str) -> bool:
    return rules.can(user, task, action)


def spec() -> ModuleSpec:
    from .api import router

    return ModuleSpec("tasks", router, resolve, can, audience=rules.audience, set_progress=service.set_progress,
                      title=lambda task: task.title, transfer=transfer.transfer, search=search.search)
