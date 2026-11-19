"""Registration of the projects module in the workspace registry."""
from typing import Any

from accounts.models import User
from workspace.models import Subject
from workspace.registry import ModuleSpec

from . import rules, search, transfer
from .models import Project


def resolve(subject: Subject) -> Project | None:
    return Project.objects.select_related("subject").filter(subject=subject).first()


def can(user: User, project: Any, action: str) -> bool:
    return rules.can(user, project, action)


def spec() -> ModuleSpec:
    from .api import router

    return ModuleSpec("projects", router, resolve, can, audience=rules.audience, title=lambda p: p.name,
                      transfer=transfer.transfer, search=search.search)
