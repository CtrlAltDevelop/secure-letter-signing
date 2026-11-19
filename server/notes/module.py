"""Registration of the notes module. Everything is owner-only: nobody else (not even the manager) sees a note."""
from typing import Any

from ninja.errors import HttpError

from accounts.models import User
from workspace.models import Subject
from workspace.registry import ModuleSpec

from . import search
from .models import Note

MAX_IMAGES = 10
OWNER_ACTIONS = {"see", "label", "comment", "moderate"}  # "comment" is what workspace files need to upload


def resolve(subject: Subject) -> Note | None:
    return Note.objects.select_related("subject").filter(subject=subject).first()


def can(user: User, note: Any, action: str) -> bool:
    return note.owner_id == user.id and action in OWNER_ACTIONS


def check_file(note: Any, content_type: str, active_count: int) -> None:
    if not content_type.startswith("image/"):
        raise HttpError(422, "Notes take images only")
    if active_count >= MAX_IMAGES:
        raise HttpError(422, f"At most {MAX_IMAGES} images per note")


def spec() -> ModuleSpec:
    from .api import router

    return ModuleSpec("notes", router, resolve, can, audience=lambda note: set(), title=lambda n: n.title,
                      file_check=check_file, search=search.search)
