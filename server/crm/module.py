"""Registration of the crm module in the workspace registry."""
from typing import Any

from accounts.models import User
from workspace.models import Subject
from workspace.registry import ModuleSpec

from . import rules, search, transfer
from .models import Customer


def resolve(subject: Subject) -> Customer | None:
    return Customer.objects.select_related("subject").filter(subject=subject).first()


def can(user: User, customer: Any, action: str) -> bool:
    return rules.can(user, customer, action)


def spec() -> ModuleSpec:
    from .api import router

    return ModuleSpec("crm", router, resolve, can, audience=rules.audience, title=lambda c: c.name, search=search.search, transfer=transfer.transfer)
