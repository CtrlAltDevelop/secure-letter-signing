"""Bookmarks and pins. Visibility is always asked of the target's module (`resolve`/`can`, or `bookmark_check`).

Subject-backed bookmarks store the subject id in `target_id`; clients may send either the subject id or the module
object's own id (a task id, a letter id...), it is normalised here.
"""
from uuid import UUID

from django.db import transaction
from django.db.models import Max
from ninja.errors import HttpError

from accounts.models import User

from . import registry
from .models import Bookmark, Pin, Subject
from .textbox import open_text, seal_text

PINNABLE = ("projects", "crm", "chat")
MAX_ACTIVE_BOOKMARKS = 1000
MAX_PINS = 50


def _uuid(raw: str) -> UUID | None:
    try:
        return UUID(str(raw))
    except ValueError:
        return None


def subject_for(module: str, raw_id: str) -> Subject | None:
    """The subject of `module` addressed by its subject id or by the module object's id."""
    key = _uuid(raw_id)
    if key is None:
        return None
    found = Subject.objects.filter(pk=key, module=module).first()
    if found:
        return found
    for rel in Subject._meta.related_objects:
        if rel.one_to_one and rel.related_model._meta.app_label == module:
            sid = rel.related_model.objects.filter(pk=key).values_list(rel.field.attname, flat=True).first()
            if sid:
                return Subject.objects.filter(pk=sid).first()
    return None


def _spec(module: str) -> registry.ModuleSpec:
    registry.require_module(module)
    spec = registry.get(module)
    if spec is None:
        raise HttpError(404, "Not found")
    return spec


def visible_target(user: User, module: str, raw_id: str) -> tuple[Subject | None, str, str] | None:
    """(subject or None, normalised target id, title) when the user may see the target, else None."""
    spec = _spec(module)
    subject = subject_for(module, raw_id)
    if subject is not None:
        obj = spec.resolve(subject)
        if obj is None or not spec.can(user, obj, "see"):
            return None
        return subject, str(subject.id), (spec.title(obj) if spec.title else "")[:200]
    if spec.bookmark_check is None:
        return None
    title = spec.bookmark_check(user, str(raw_id))
    return None if title is None else (None, str(raw_id), title[:200])


@transaction.atomic
def put_bookmark(user: User, module: str, raw_id: str, note: str | None) -> Bookmark:
    found = visible_target(user, module, raw_id)
    if found is None:
        raise HttpError(404, "Not found")
    subject, target_id, title = found
    row, created = Bookmark.objects.select_for_update().get_or_create(
        user=user, target_module=module, target_id=target_id,
        defaults={"subject": subject, "title": title, "note": seal_text(note or "")})
    if not created:
        row.active, row.title, row.subject = True, title, subject
        if note is not None:
            row.note = seal_text(note)
        row.save(update_fields=["active", "title", "subject", "note"])
    elif Bookmark.objects.filter(user=user, active=True).count() > MAX_ACTIVE_BOOKMARKS:
        raise HttpError(422, f"At most {MAX_ACTIVE_BOOKMARKS} bookmarks")
    return row


def list_bookmarks(user: User, module: str = "") -> list[dict]:
    """Active bookmarks the user can still see, newest first; the title is refreshed from the target."""
    rows = Bookmark.objects.filter(user=user, active=True).select_related("subject").order_by("-created_at", "-id")
    if module:
        rows = rows.filter(target_module=module)
    enabled = registry.enabled_modules()
    out = []
    for row in rows[:MAX_ACTIVE_BOOKMARKS]:
        if row.target_module not in enabled:
            continue
        found = visible_target(user, row.target_module, row.target_id)
        if found is None:
            continue
        out.append(bookmark_dict(row, found[2], found[0]))
    return out


def bookmark_dict(row: Bookmark, title: str, subject: Subject | None) -> dict:
    spec = registry.get(row.target_module)
    obj = spec.resolve(subject) if spec and subject else None
    return {"id": row.id, "module": row.target_module, "kind": subject.kind if subject else "message",
            "target_id": row.target_id, "subject_id": str(subject.id) if subject else None,
            "object_id": str(obj.pk) if obj is not None else row.target_id, "title": title,
            "note": open_text(row.note), "created_at": row.created_at}


def deactivate_bookmark(user: User, bookmark_id: int) -> None:
    if not Bookmark.objects.filter(pk=bookmark_id, user=user, active=True).update(active=False):
        raise HttpError(404, "Not found")


@transaction.atomic
def put_pin(user: User, subject_id: UUID) -> Pin:
    subject = Subject.objects.filter(pk=subject_id).first()
    if subject is None or subject.module not in PINNABLE:
        raise HttpError(422, "Only projects, customer files and conversations can be pinned")
    spec = _spec(subject.module)
    obj = spec.resolve(subject)
    if obj is None or not spec.can(user, obj, "see"):
        raise HttpError(404, "Not found")
    row, created = Pin.objects.select_for_update().get_or_create(user=user, subject=subject)
    if created or not row.active:
        top = Pin.objects.filter(user=user, active=True).aggregate(m=Max("rank"))["m"]
        row.rank, row.active = (top or 0) + 1, True
        row.save(update_fields=["rank", "active"])
        if Pin.objects.filter(user=user, active=True).count() > MAX_PINS:
            raise HttpError(422, f"At most {MAX_PINS} pins")
    return row


def list_pins(user: User) -> list[dict]:
    enabled = registry.enabled_modules()
    out = []
    for pin in Pin.objects.filter(user=user, active=True).select_related("subject").order_by("rank", "id"):
        subject = pin.subject
        spec = registry.get(subject.module)
        obj = spec.resolve(subject) if spec and subject.module in enabled else None
        if obj is None or not spec.can(user, obj, "see"):
            continue
        out.append({"subject_id": str(subject.id), "module": subject.module, "kind": subject.kind,
                    "title": spec.title(obj) if spec.title else ""})
    return out


def deactivate_pin(user: User, subject_id: UUID) -> None:
    if not Pin.objects.filter(user=user, subject_id=subject_id, active=True).update(active=False):
        raise HttpError(404, "Not found")
