from datetime import datetime
from uuid import UUID

from ninja import Field, Schema

from workspace.schemas import UserRef

MAX_TEXT = 4000
MAX_MEMBERS = 500
MAX_MENTIONS = 50


class ConversationIn(Schema):
    kind: str = Field(pattern="^(group|channel)$")
    name: str = Field(min_length=1, max_length=100)
    description: str = Field("", max_length=500)
    is_public: bool = False
    member_ids: list[int] = Field(default_factory=list, max_length=MAX_MEMBERS)
    post_policy: str | None = Field(None, pattern="^(admins|all)$")  # default: all for groups, admins for channels


class ConversationPatch(Schema):
    name: str | None = Field(None, min_length=1, max_length=100)
    description: str | None = Field(None, max_length=500)
    is_public: bool | None = None
    post_policy: str | None = Field(None, pattern="^(admins|all)$")
    archived: bool | None = None


class MemberIn(Schema):
    user_id: int
    role: str = Field("member", pattern="^(admin|member)$")


class MuteIn(Schema):
    muted: bool


class PinIn(Schema):
    pinned: bool


class DmIn(Schema):
    user_id: int


class MessageIn(Schema):
    text: str = Field("", max_length=MAX_TEXT)
    reply_to_id: int | None = None
    mentions: list[int] = Field(default_factory=list, max_length=MAX_MENTIONS)
    file_id: UUID | None = None
    kind: str | None = Field(None, pattern="^(text|file|voice)$")  # default: file when file_id is set, else text


class MessageEdit(Schema):
    text: str = Field(max_length=MAX_TEXT)


class ReadIn(Schema):
    seq: int = Field(ge=0)


class ToTaskIn(Schema):
    title: str | None = Field(None, min_length=1, max_length=200)
    owner_ids: list[int] = Field(default_factory=list, max_length=50)
    due_at: datetime | None = None
    project_id: UUID | None = None


class FileRef(Schema):
    id: UUID
    name: str
    content_type: str
    size: int


class ReplyRef(Schema):
    id: int
    seq: int
    author_id: int
    preview: str


class MessageOut(Schema):
    id: int
    conversation_id: UUID
    seq: int
    author: UserRef
    kind: str
    text: str
    reply_to: ReplyRef | None
    mentions: list[int]
    file: FileRef | None
    data: dict | None  # system messages: {"event": "task_created", "task_id": ..}
    created_at: datetime
    edited_at: datetime | None
    edited: bool
    deleted: bool
    pinned: bool


class MemberOut(Schema):
    user: UserRef
    role: str
    muted: bool


class CanOut(Schema):
    post: bool
    admin: bool
    join: bool


class ConversationOut(Schema):
    id: UUID
    subject_id: UUID
    kind: str
    name: str
    description: str
    is_public: bool
    post_policy: str
    project_id: UUID | None
    customer_id: UUID | None
    archived: bool
    creator_id: int
    member_count: int
    is_member: bool
    my_role: str | None
    muted: bool
    pinned: bool
    unread: int
    mention_unread: int
    last_message_preview: str
    last_message_at: datetime | None
    last_seq: int
    last_read_seq: int
    other_user: UserRef | None  # dm: the other person
    members: list[MemberOut] | None  # detail only, members only
    can: CanOut
    created_at: datetime


class UnreadEntry(Schema):
    conversation_id: UUID
    unread: int
    mention_unread: int
    muted: bool


class UnreadOut(Schema):
    total: int  # unread messages in conversations that are not muted
    mentions: int  # unread mentions, muted conversations included
    conversations: list[UnreadEntry]


class SeenEntry(Schema):
    user: UserRef
    at: datetime


class SeenOut(Schema):
    tracked: bool  # false for conversations above the receipt cap
    seen: list[SeenEntry]
