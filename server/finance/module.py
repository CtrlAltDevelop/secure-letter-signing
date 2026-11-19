"""Registration of the finance module in the workspace registry."""
from typing import Any

from accounts.models import User
from workspace.models import Subject
from workspace.registry import ModuleSpec

from . import rules, search
from .models import FinanceDoc


def resolve(subject: Subject) -> FinanceDoc | None:
    return FinanceDoc.objects.select_related("subject").filter(subject=subject).first()


def can(user: User, doc: Any, action: str) -> bool:
    return rules.can(user, doc, action)


def spec() -> ModuleSpec:
    from .api import router

    # Titles stay empty: amounts and descriptions never travel in events or notifications.
    return ModuleSpec("finance", router, resolve, can, audience=rules.audience, title=lambda d: "", search=search.search)
