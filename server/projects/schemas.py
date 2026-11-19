from datetime import date, datetime
from uuid import UUID

from ninja import Field, Schema

from tasks.schemas import DescriptionIn, DescriptionOut, TaskBrief
from workspace.schemas import UserRef

ROLE = "^(manager|member|viewer)$"
KIND = "^(todo|doing|done)$"
STATUS = "^(active|done|archived)$"
MAX_MEMBERS = 500


class MemberIn(Schema):
    user_id: int
    role: str = Field(pattern=ROLE)


class GroupAccessIn(Schema):
    add: list[MemberIn] = []  # added (or role-changed) on every active project of the group
    remove: list[int] = []  # deactivated on every project of the group (owners stay)


class GroupAccessOut(Schema):
    group_id: int
    projects_changed: int


class ProjectIn(Schema):
    name: str = Field(min_length=1, max_length=200)
    description: DescriptionIn | None = None
    group_id: int | None = None
    color: int = Field(0, ge=0, le=31)
    start_date: date | None = None
    end_date: date | None = None
    members: list[MemberIn] = Field(default_factory=list, max_length=MAX_MEMBERS)  # the owner is added as manager
    members_can_edit_tasks: bool = True
    members_can_extend: bool = True
    require_removal_approval: bool = False


class ProjectPatch(Schema):
    """Only the fields present in the request change (`null` clears group, dates and description)."""

    name: str | None = Field(None, min_length=1, max_length=200)
    description: DescriptionIn | None = None
    group_id: int | None = None
    color: int | None = Field(None, ge=0, le=31)
    status: str | None = Field(None, pattern=STATUS)
    start_date: date | None = None
    end_date: date | None = None
    members_can_edit_tasks: bool | None = None
    members_can_extend: bool | None = None
    require_removal_approval: bool | None = None


class ProjectCopyIn(Schema):
    name: str = Field(min_length=1, max_length=200)


class ColumnIn(Schema):
    title: str = Field(min_length=1, max_length=100)
    kind: str = Field("doing", pattern=KIND)


class ColumnPatch(Schema):
    title: str | None = Field(None, min_length=1, max_length=100)
    kind: str | None = Field(None, pattern=KIND)
    active: bool | None = None  # false hides an empty column (kept in the database)


class ColumnOrder(Schema):
    ids: list[int] = Field(max_length=100)


class GroupIn(Schema):
    name: str = Field(min_length=1, max_length=100)
    scope: str = Field("personal", pattern="^(org|personal)$")


class GroupPatch(Schema):
    name: str | None = Field(None, min_length=1, max_length=100)
    rank: int | None = None
    active: bool | None = None


class GroupOut(Schema):
    id: int
    name: str
    scope: str
    rank: int
    active: bool


class MemberOut(Schema):
    user: UserRef
    role: str


class ColumnOut(Schema):
    id: int
    title: str
    kind: str
    rank: int
    task_count: int


class ProjectBrief(Schema):
    id: UUID
    subject_id: UUID
    name: str
    color: int
    status: str
    group_id: int | None
    owner_id: int
    progress: int
    start_date: date | None
    end_date: date | None
    my_role: str
    member_count: int
    updated_at: datetime


class CanOut(Schema):
    see: bool
    comment: bool
    label: bool
    edit: bool
    moderate: bool
    create_task: bool


class ProjectOut(ProjectBrief):
    members_can_edit_tasks: bool
    members_can_extend: bool
    require_removal_approval: bool
    description: DescriptionOut
    owner: UserRef
    members: list[MemberOut]
    columns: list[ColumnOut]
    can: CanOut
    created_at: datetime


class ColumnTasks(Schema):
    id: int
    title: str
    kind: str
    rank: int
    tasks: list[TaskBrief]


class ProjectTasksOut(Schema):
    view: str
    columns: list[ColumnTasks] = []  # board only
    tasks: list[TaskBrief] = []  # list and calendar
