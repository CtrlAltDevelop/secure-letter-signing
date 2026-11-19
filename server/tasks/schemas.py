from datetime import datetime
from uuid import UUID

from ninja import Field, Schema

from workspace.schemas import UserRef

MAX_PEOPLE = 50
MAX_CHECKLIST = 200
PRIORITY = "^(low|normal|high|urgent)$"


class DescriptionIn(Schema):
    text: str = Field("", max_length=50_000)


class TaskIn(Schema):
    title: str = Field(min_length=1, max_length=200)
    description: DescriptionIn | None = None
    priority: str = Field("normal", pattern=PRIORITY)
    start_at: datetime | None = None
    due_at: datetime | None = None
    all_day: bool = False
    owner_ids: list[int] = Field(default_factory=list, max_length=MAX_PEOPLE)  # empty = the creator
    approver_ids: list[int] = Field(default_factory=list, max_length=MAX_PEOPLE)
    follower_ids: list[int] = Field(default_factory=list, max_length=MAX_PEOPLE)
    checklist: list[str] = Field(default_factory=list, max_length=MAX_CHECKLIST)
    label_ids: list[int] = Field(default_factory=list, max_length=200)
    project_id: UUID | None = None
    column_id: int | None = None  # with project_id: the column to start in (default: the first "todo" column)
    weight: int = Field(1, ge=1, le=10)  # weight of its progress in the project average
    customer_id: UUID | None = None  # a customer file the caller is a manager/member of


class TaskPatch(Schema):
    """Only the fields present in the request are changed (`null` clears due/start/description)."""

    version: int
    title: str | None = Field(None, min_length=1, max_length=200)
    description: DescriptionIn | None = None
    priority: str | None = Field(None, pattern=PRIORITY)
    start_at: datetime | None = None
    due_at: datetime | None = None
    all_day: bool | None = None
    progress: int | None = Field(None, ge=0, le=100)
    progress_mode: str | None = Field(None, pattern="^(manual|checklist)$")
    project_id: UUID | None = None
    weight: int | None = Field(None, ge=1, le=10)
    customer_id: UUID | None = None  # null unlinks


class PeopleIn(Schema):
    owner_ids: list[int] = Field(min_length=1, max_length=MAX_PEOPLE)
    approver_ids: list[int] = Field(default_factory=list, max_length=MAX_PEOPLE)
    follower_ids: list[int] = Field(default_factory=list, max_length=MAX_PEOPLE)


class ChecklistAdd(Schema):
    text: str = Field(min_length=1, max_length=300)


class ChecklistPatch(Schema):
    text: str | None = Field(None, min_length=1, max_length=300)
    done: bool | None = None
    active: bool | None = None  # false removes the item (kept in the database)


class ChecklistOrder(Schema):
    item_ids: list[int] = Field(max_length=MAX_CHECKLIST)


class NoteIn(Schema):
    note: str = Field("", max_length=2000)


class DecisionIn(Schema):
    decision: str = Field(pattern="^(approve|reject)$")
    note: str = Field("", max_length=2000)


class ChecklistCount(Schema):
    done: int
    total: int


class TaskBrief(Schema):
    id: UUID
    subject_id: UUID
    title: str
    status: str
    priority: str
    progress: int
    due_at: datetime | None
    all_day: bool
    weight: int
    hidden: bool
    project_id: UUID | None
    column_id: int | None
    rank: int
    customer_id: UUID | None = None  # only set when the caller is a member of that customer file
    customer_name: str | None = None
    owner_ids: list[int]
    my_roles: list[str]
    label_ids: list[int]
    checklist: ChecklistCount
    unseen: bool
    updated_at: datetime


class ApproverOut(Schema):
    user: UserRef
    position: int
    decision: str
    decided_at: datetime | None


class ChecklistItemOut(Schema):
    id: int
    text: str
    done: bool
    done_by: UserRef | None
    done_at: datetime | None


class MoveIn(Schema):
    project_id: UUID | None = None  # null = a personal task again
    column_id: int | None = None
    before_id: UUID | None = None  # place the task just before this one (same target column); null = at the end


class CopyIn(Schema):
    project_id: UUID | None = None


class RemovalNoteIn(Schema):
    note: str = Field("", max_length=2000)


class RemovalDecisionIn(Schema):
    decision: str = Field(pattern="^(approve|reject)$")
    note: str = Field("", max_length=2000)


class RemovalOut(Schema):
    status: str
    requested_by: UserRef
    note: str
    decided_by: UserRef | None
    decision_note: str
    created_at: datetime
    decided_at: datetime | None


class CanOut(Schema):
    request_removal: bool
    decide_removal: bool
    move: bool
    edit: bool
    progress: bool
    approve: bool
    comment: bool
    complete: bool
    reopen: bool


class DescriptionOut(Schema):
    text: str


class TaskOut(TaskBrief):
    description: DescriptionOut
    creator: UserRef
    owners: list[UserRef]
    approvers: list[ApproverOut]
    followers: list[UserRef]
    checklist_items: list[ChecklistItemOut]
    start_at: datetime | None
    progress_mode: str
    version: int
    completed_at: datetime | None
    created_at: datetime
    can: CanOut
    comment_count: int
    file_count: int
    removal: RemovalOut | None
