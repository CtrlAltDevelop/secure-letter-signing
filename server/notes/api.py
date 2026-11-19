"""Notes API (mounted at /api/notes): personal notes, visible to their owner only (everyone else gets 404)."""
from uuid import UUID

from django.db.models import Q
from ninja import Router

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, user_of
from accounts.models import User
from workspace import registry
from workspace.access import my_label_ids
from workspace.models import File, Label, SubjectLabel
from workspace.textbox import open_text

from . import service
from .models import Note
from .schemas import (ArchiveIn, BodyIn, ChecklistAdd, ChecklistOrder, ChecklistPatch, ItemOut, NoteIn, NoteOut,
                      NotePatch, PinIn)

router = Router(tags=["notes"], auth=BearerAuth())
ERRORS = {404: Detail, 422: Detail}
MAX_LIMIT = 200


def _gate() -> None:
    registry.require_module("notes")


def _out(user: User, note: Note) -> NoteOut:
    note = Note.objects.select_related("subject").get(pk=note.pk)
    items = service.active_items(note).order_by("rank", "id")
    return NoteOut(
        id=note.id, subject_id=note.subject_id, title=note.title, body=BodyIn(text=open_text(note.body)),
        color=note.color, pinned=note.pinned, archived=note.archived,
        checklist_items=[ItemOut(id=i.id, text=i.text, done=i.done) for i in items],
        label_ids=my_label_ids(user, note.subject),
        image_count=File.objects.filter(subject=note.subject, active=True).count(),
        created_at=note.created_at, updated_at=note.updated_at)


@router.get("", response=list[NoteOut])
def list_notes(request, q: str = "", label: int | None = None, pinned: bool | None = None, archived: bool = False,
               limit: int = 100, offset: int = 0):
    """Pinned first, then most recently updated. Archived notes only with `archived=true`."""
    _gate()
    user = user_of(request)
    rows = Note.objects.filter(owner=user, archived=archived).select_related("subject")
    if q:
        rows = rows.filter(Q(title__icontains=q) | Q(checklist__text__icontains=q, checklist__active=True)).distinct()
    if pinned is not None:
        rows = rows.filter(pinned=pinned)
    if label is not None:
        mine = SubjectLabel.objects.filter(active=True, label_id=label, label__active=True).filter(
            Q(label__scope=Label.ORG) | Q(label__owner=user))
        rows = rows.filter(subject_id__in=mine.values("subject_id"))
    start = max(offset, 0)
    page = rows.order_by("-pinned", "-updated_at", "-created_at")[start : start + max(min(limit, MAX_LIMIT), 0)]
    return [_out(user, n) for n in page]


@router.post("", response={201: NoteOut, **ERRORS})
def create_note(request, data: NoteIn):
    _gate()
    user = user_of(request)
    return 201, _out(user, service.create(user, data))


@router.get("/{uuid:note_id}", response={200: NoteOut, 404: Detail})
def get_note(request, note_id: UUID):
    _gate()
    user = user_of(request)
    return _out(user, service.owned(user, note_id))


@router.patch("/{uuid:note_id}", response={200: NoteOut, **ERRORS})
def patch_note(request, note_id: UUID, data: NotePatch):
    _gate()
    user = user_of(request)
    return _out(user, service.update(user, note_id, data))


@router.post("/{uuid:note_id}/checklist", response={201: NoteOut, **ERRORS})
def add_item(request, note_id: UUID, data: ChecklistAdd):
    _gate()
    user = user_of(request)
    return 201, _out(user, service.add_item(user, note_id, data.text))


@router.patch("/{uuid:note_id}/checklist/{int:item_id}", response={200: NoteOut, **ERRORS})
def patch_item(request, note_id: UUID, item_id: int, data: ChecklistPatch):
    _gate()
    user = user_of(request)
    return _out(user, service.patch_item(user, note_id, item_id, data))


@router.put("/{uuid:note_id}/checklist/order", response={200: NoteOut, **ERRORS})
def order_items(request, note_id: UUID, data: ChecklistOrder):
    _gate()
    user = user_of(request)
    return _out(user, service.reorder(user, note_id, data.item_ids))


@router.post("/{uuid:note_id}/pin", response={200: NoteOut, **ERRORS})
def pin(request, note_id: UUID, data: PinIn):
    _gate()
    user = user_of(request)
    return _out(user, service.set_flag(user, note_id, "pinned", data.pinned))


@router.post("/{uuid:note_id}/archive", response={200: NoteOut, **ERRORS})
def archive(request, note_id: UUID, data: ArchiveIn | None = None):
    _gate()
    user = user_of(request)
    return _out(user, service.set_flag(user, note_id, "archived", data.archived if data else True))
