"""Module registry: each module app registers a `ModuleSpec` in `AppConfig.ready()`.

Shared endpoints never decide access themselves: they resolve the subject's module here and ask `spec.can`.
Plan gating later = one plan -> modules map inside `enabled_modules()`.
"""
from collections.abc import Callable, Iterable
from contextvars import ContextVar
from dataclasses import dataclass
from typing import Any

from ninja import Router
from ninja.errors import HttpError

from accounts.models import User
from core.brand import brand_modules

from .models import Subject

KNOWN_MODULES = ("letters", "tasks", "projects", "meetings", "notes", "polls", "crm", "finance", "sales", "chat", "gantt")
PLAN = "advanced"


@dataclass(frozen=True)
class ModuleSpec:
    code: str
    router: Router | None
    resolve: Callable[[Subject], Any | None]  # the module's object for a subject (None when it is gone)
    can: Callable[[User, Any, str], bool]  # actions: "see", "label", "comment", "progress", "moderate", ...
    # Optional: user ids who should get live events about the object (comments, files); None = nobody.
    audience: Callable[[Any], Iterable[int]] | None = None
    # Optional: apply a progress value from a `report` comment (caller already passed can(.., "progress")).
    # Returns the progress now stored. None = the module has no progress, so reports are refused.
    set_progress: Callable[[Any, User, int], int] | None = None
    # Optional: the object's display title (event/notification titles); None = no title.
    title: Callable[[Any], str] | None = None
    # Optional: veto an upload (obj, content_type, active_file_count); raise HttpError to refuse.
    file_check: Callable[[Any, str, int], None] | None = None
    # Optional: move a user's open work to a colleague (from_user, to_user, actor). Returns how many things moved:
    # an int (counted under the module code) or {key: count}. Runs inside one transaction with the other modules.
    transfer: Callable[[User, User, User], int | dict[str, int]] | None = None
    # Optional: extra content types accepted besides ATTACHMENT_TYPES, and a per-subject cap replacing the default.
    file_types: frozenset[str] = frozenset()
    max_files: int | None = None
    # Optional: unified search `(user, q, limit) -> [{module, kind, id, subject_id, title, snippet, at}]` over what the
    # user may see (identifying fields only). Called by `GET /search` for enabled modules.
    search: Callable[[User, str, int], list[dict]] | None = None
    # Optional: bookmark target that is not a Subject (chat messages): `(user, target_id) -> title | None`; None = the
    # user cannot see the target.
    bookmark_check: Callable[[User, str], str | None] | None = None


_REGISTRY: dict[str, ModuleSpec] = {}


def register(spec: ModuleSpec) -> None:
    if spec.code in _REGISTRY:
        raise ValueError(f"module {spec.code!r} is already registered")
    _REGISTRY[spec.code] = spec


def unregister(code: str) -> None:
    """For tests."""
    _REGISTRY.pop(code, None)


def get(code: str) -> ModuleSpec | None:
    return _REGISTRY.get(code)


def all_specs() -> list[ModuleSpec]:
    return list(_REGISTRY.values())


def module_codes() -> list[str]:
    """Every module this server knows: the planned ones plus anything registered."""
    return [*KNOWN_MODULES, *(c for c in _REGISTRY if c not in KNOWN_MODULES)]


_viewer: ContextVar[User | None] = ContextVar("workspace_viewer", default=None)


def set_current_user(user: User | None) -> None:
    """Called by the API auth for every request: guests only get `GUEST_MODULES` from `enabled_modules()`."""
    _viewer.set(user)


def enabled_modules() -> set[str]:
    from accounts.guests import GUEST_MODULES

    listed = brand_modules()
    mods = set(module_codes()) if listed is None else set(listed)
    viewer = _viewer.get()
    return mods & GUEST_MODULES if viewer is not None and viewer.is_guest else mods


def require_module(code: str) -> None:
    """404 when the module is switched off for this deployment."""
    if code not in enabled_modules():
        raise HttpError(404, "Not found")
