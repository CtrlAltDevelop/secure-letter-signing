"""Registration of the polls module in the workspace registry."""
from typing import Any

from accounts.models import User
from workspace.models import Subject
from workspace.registry import ModuleSpec

from . import rules
from .models import Poll


def resolve(subject: Subject) -> Poll | None:
    return Poll.objects.select_related("subject", "target_subject").filter(subject=subject).first()


def can(user: User, poll: Any, action: str) -> bool:
    return rules.can(user, poll, action)


def spec() -> ModuleSpec:
    from .api import router

    return ModuleSpec("polls", router, resolve, can, audience=rules.audience, title=lambda p: p.title)
