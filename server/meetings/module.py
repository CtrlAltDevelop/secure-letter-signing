"""Registration of the meetings module in the workspace registry."""
from typing import Any

from accounts.models import User
from workspace.models import Subject
from workspace.registry import ModuleSpec

from . import rules, search
from .models import Meeting


def resolve(subject: Subject) -> Meeting | None:
    return Meeting.objects.select_related("subject").filter(subject=subject).first()


def can(user: User, meeting: Any, action: str) -> bool:
    return rules.can(user, meeting, action)


def spec() -> ModuleSpec:
    from .api import router

    return ModuleSpec("meetings", router, resolve, can, audience=rules.audience, title=lambda m: m.title, search=search.search)
