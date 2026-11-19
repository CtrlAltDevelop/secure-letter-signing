"""Registration of the letters module in the workspace registry (letters and secretariat entries are subjects)."""
from collections.abc import Iterable
from typing import Any

from accounts.models import User
from workspace.models import Subject
from workspace.registry import ModuleSpec

from . import rules, search
from .models import Letter, SecretariatEntry

ENTRY_KIND = "secretariat_entry"
LETTER_KIND = "letter"
ENTRY_ACTIONS = {"see", "comment", "label", "moderate"}  # the secretariat works on its own register rows


def resolve(subject: Subject) -> Letter | SecretariatEntry | None:
    if subject.kind == ENTRY_KIND:
        return SecretariatEntry.objects.filter(subject=subject).first()
    return Letter.objects.filter(subject=subject).first()


def can(user: User, obj: Any, action: str) -> bool:
    if isinstance(obj, SecretariatEntry):
        return action in ENTRY_ACTIONS and rules.has_secretariat(user)
    if action in ("see", "comment", "label"):
        return rules.can_see(user, obj)
    if action == "moderate":
        return obj.creator_id == user.id
    return False


def audience(obj: Any) -> Iterable[int]:
    if isinstance(obj, SecretariatEntry):
        return User.objects.filter(is_active=True, grants__code=rules.SECRETARIAT).values_list("id", flat=True)
    return rules.audience_ids(obj)


def title(obj: Any) -> str:
    return obj.title


def spec() -> ModuleSpec:
    from .api import router

    return ModuleSpec("letters", router, resolve, can, audience=audience, title=title, search=search.search)
