"""Bookmarks, pins and unified search endpoints."""
from datetime import datetime
from uuid import UUID

from ninja import Field, Router, Schema
from ninja.errors import HttpError

from accounts import ratelimit
from accounts.api_auth import Detail
from accounts.auth import BearerAuth, user_of

from . import bookmarks, search

router = Router(tags=["bookmarks"], auth=BearerAuth())
SEARCH_PER_MINUTE = 60


class BookmarkIn(Schema):
    module: str = Field(min_length=1, max_length=32)
    id: str = Field(min_length=1, max_length=64)
    note: str | None = Field(None, max_length=2000)


class BookmarkOut(Schema):
    id: int
    module: str
    kind: str
    target_id: str
    subject_id: str | None
    object_id: str
    title: str
    note: str
    created_at: datetime


class PinIn(Schema):
    subject_id: UUID


class PinOut(Schema):
    subject_id: str
    object_id: str
    module: str
    kind: str
    title: str


class SearchHit(Schema):
    module: str
    kind: str
    id: str
    subject_id: str | None
    title: str
    snippet: str
    at: datetime | None


@router.get("/bookmarks", response=list[BookmarkOut])
def list_bookmarks(request, module: str = ""):
    return bookmarks.list_bookmarks(user_of(request), module)


@router.put("/bookmarks", response={200: BookmarkOut, 404: Detail, 422: Detail})
def put_bookmark(request, data: BookmarkIn):
    user = user_of(request)
    row = bookmarks.put_bookmark(user, data.module, data.id, data.note)
    found = bookmarks.visible_target(user, row.target_module, row.target_id)
    return bookmarks.bookmark_dict(row, found[2] if found else row.title, found[0] if found else None)


@router.delete("/bookmarks/{int:bookmark_id}", response={204: None, 404: Detail})
def delete_bookmark(request, bookmark_id: int):
    bookmarks.deactivate_bookmark(user_of(request), bookmark_id)
    return 204, None


@router.get("/pins", response=list[PinOut])
def list_pins(request):
    return bookmarks.list_pins(user_of(request))


@router.put("/pins", response={200: list[PinOut], 404: Detail, 422: Detail})
def put_pin(request, data: PinIn):
    user = user_of(request)
    bookmarks.put_pin(user, data.subject_id)
    return bookmarks.list_pins(user)


@router.delete("/pins/{uuid:subject_id}", response={204: None, 404: Detail})
def delete_pin(request, subject_id: UUID):
    bookmarks.deactivate_pin(user_of(request), subject_id)
    return 204, None


@router.get("/search", response={200: list[SearchHit], 422: Detail, 429: Detail})
def unified_search(request, q: str = "", modules: str = "", limit: int = 20):
    user = user_of(request)
    text = q.strip()
    if len(text) < search.MIN_QUERY:
        raise HttpError(422, f"The query needs at least {search.MIN_QUERY} characters")
    ratelimit.hit("search", str(user.id), SEARCH_PER_MINUTE, window=60)
    wanted = {m.strip() for m in modules.split(",") if m.strip()}
    return search.run(user, text, wanted, max(1, min(limit, search.MAX_LIMIT)))
