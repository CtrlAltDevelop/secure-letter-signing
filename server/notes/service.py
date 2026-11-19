"""Note creation and editing. Every function takes the owner; other users get 404 before anything else."""
from uuid import UUID

from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja.errors import HttpError

from accounts.models import User
from workspace.models import Subject
from workspace.textbox import seal_text

from .models import Note, NoteChecklistItem
from .schemas import ChecklistPatch, NoteIn, NotePatch

RANK_GAP = 65_536
MAX_ITEMS = 200


def owned(user: User, note_id: UUID, *, lock: bool = False) -> Note:
    """The caller's own note; 404 for anyone else's (they cannot tell it exists)."""
    rows = Note.objects.select_related("subject")
    return get_object_or_404(rows.select_for_update() if lock else rows, pk=note_id, owner=user)


def touch(note: Note, **fields) -> None:
    for name, value in fields.items():
        setattr(note, name, value)
    note.updated_at = timezone.now()
    note.save()


def active_items(note: Note):
    return NoteChecklistItem.objects.filter(note=note, active=True)


def _next_rank(note: Note) -> int:
    last = active_items(note).order_by("-rank").first()
    return (last.rank if last else 0) + RANK_GAP


@transaction.atomic
def create(user: User, data: NoteIn) -> Note:
    texts = [t.strip() for t in data.checklist]
    if not all(texts):
        raise HttpError(422, "Checklist items cannot be empty")
    subject = Subject.objects.create(module="notes", kind="note")
    note = Note.objects.create(subject=subject, owner=user, title=data.title.strip(), color=data.color,
                               body=seal_text(data.body.text if data.body else ""), pinned=data.pinned)
    NoteChecklistItem.objects.bulk_create(
        [NoteChecklistItem(note=note, text=t, rank=(i + 1) * RANK_GAP) for i, t in enumerate(texts)])
    return note


@transaction.atomic
def update(user: User, note_id: UUID, data: NotePatch) -> Note:
    note = owned(user, note_id, lock=True)
    fields = data.model_fields_set
    changes = {}
    if "title" in fields and data.title is not None:
        changes["title"] = data.title.strip()
    if "color" in fields and data.color is not None:
        changes["color"] = data.color
    if "body" in fields:
        changes["body"] = seal_text(data.body.text if data.body else "")
    if changes:
        touch(note, **changes)
    return note


@transaction.atomic
def add_item(user: User, note_id: UUID, text: str) -> Note:
    note = owned(user, note_id, lock=True)
    if active_items(note).count() >= MAX_ITEMS:
        raise HttpError(422, f"At most {MAX_ITEMS} checklist items")
    NoteChecklistItem.objects.create(note=note, text=text.strip(), rank=_next_rank(note))
    touch(note)
    return note


@transaction.atomic
def patch_item(user: User, note_id: UUID, item_id: int, data: ChecklistPatch) -> Note:
    note = owned(user, note_id, lock=True)
    item = get_object_or_404(active_items(note), pk=item_id)
    for name in ("text", "done", "active"):
        value = getattr(data, name)
        if name in data.model_fields_set and value is not None:
            setattr(item, name, value.strip() if name == "text" else value)
    item.save()
    touch(note)
    return note


@transaction.atomic
def reorder(user: User, note_id: UUID, item_ids: list[int]) -> Note:
    note = owned(user, note_id, lock=True)
    items = {i.id for i in active_items(note)}
    if sorted(item_ids) != sorted(items):
        raise HttpError(422, "item_ids must list every active item exactly once")
    for position, item_id in enumerate(item_ids, start=1):
        NoteChecklistItem.objects.filter(pk=item_id).update(rank=position * RANK_GAP)
    touch(note)
    return note


@transaction.atomic
def set_flag(user: User, note_id: UUID, flag: str, value: bool) -> Note:
    note = owned(user, note_id, lock=True)
    if getattr(note, flag) != value:
        touch(note, **{flag: value})
    return note
