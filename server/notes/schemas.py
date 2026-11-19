from datetime import datetime
from uuid import UUID

from ninja import Field, Schema

MAX_CHECKLIST = 200


class BodyIn(Schema):
    text: str = Field("", max_length=50_000)


class NoteIn(Schema):
    title: str = Field("", max_length=200)
    body: BodyIn | None = None
    color: int = Field(0, ge=0, le=15)
    pinned: bool = False
    checklist: list[str] = Field(default_factory=list, max_length=MAX_CHECKLIST)


class NotePatch(Schema):
    title: str | None = Field(None, max_length=200)
    body: BodyIn | None = None
    color: int | None = Field(None, ge=0, le=15)


class PinIn(Schema):
    pinned: bool = True


class ArchiveIn(Schema):
    archived: bool = True


class ChecklistAdd(Schema):
    text: str = Field(min_length=1, max_length=300)


class ChecklistPatch(Schema):
    text: str | None = Field(None, min_length=1, max_length=300)
    done: bool | None = None
    active: bool | None = None  # false removes the item (kept in the database)


class ChecklistOrder(Schema):
    item_ids: list[int] = Field(max_length=MAX_CHECKLIST)


class ItemOut(Schema):
    id: int
    text: str
    done: bool


class NoteOut(Schema):
    id: UUID
    subject_id: UUID
    title: str
    body: BodyIn
    color: int
    pinned: bool
    archived: bool
    checklist_items: list[ItemOut]
    label_ids: list[int]
    image_count: int
    created_at: datetime
    updated_at: datetime
