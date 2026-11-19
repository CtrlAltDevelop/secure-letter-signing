from datetime import datetime
from uuid import UUID

from ninja import Field, Schema

from accounts.models import User

MAX_TEXT_CHARS = 20_000
MAX_MENTIONS = 50


class UserRef(Schema):
    id: int
    full_name: str
    email: str
    title: str  # the company title (job position) name, '' when none
    status_text: str


def user_ref(user: User) -> UserRef:
    title = user.org_title.name if user.org_title_id else ""
    return UserRef(id=user.id, full_name=user.full_name, email=user.email, title=title, status_text=user.status_text)


class TextBody(Schema):
    text: str = Field(max_length=MAX_TEXT_CHARS)


class CommentIn(Schema):
    body: TextBody
    parent_id: int | None = None
    kind: str = Field("comment", pattern="^(comment|report)$")
    progress: int | None = Field(None, ge=0, le=100)
    mentions: list[int] = Field(default_factory=list, max_length=MAX_MENTIONS)  # user ids; each must see the subject


class CommentPatch(Schema):
    body: TextBody


class CommentOut(Schema):
    id: int
    author: UserRef
    kind: str
    body: TextBody
    progress: int | None
    parent_id: int | None
    edited: bool
    created_at: datetime
    mentions: list[UserRef] = []
    replies: list["CommentOut"] = []


class FileOut(Schema):
    id: UUID
    name: str
    content_type: str
    size: int
    sha256: str
    uploaded_by: UserRef
    created_at: datetime


class HistoryOut(Schema):
    id: int
    actor: UserRef | None
    field: str
    old: object | None
    new: object | None
    at: datetime


class SeenOut(Schema):
    user: UserRef
    first_at: datetime
    last_at: datetime
