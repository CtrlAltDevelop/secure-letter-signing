"""Registration of the sales module in the workspace registry."""
from typing import Any

from accounts.models import User
from workspace.models import Subject
from workspace.registry import ModuleSpec

from . import rules, search, transfer
from .models import Lead


def resolve(subject: Subject) -> Lead | None:
    return Lead.objects.select_related("subject").filter(subject=subject).first()


def can(user: User, lead: Any, action: str) -> bool:
    return rules.can(user, lead, action)


def spec() -> ModuleSpec:
    from .api import router

    return ModuleSpec("sales", router, resolve, can, audience=rules.audience, title=lambda lead: lead.title, search=search.search, transfer=transfer.transfer)
