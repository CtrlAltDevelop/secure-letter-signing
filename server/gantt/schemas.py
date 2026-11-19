from datetime import date, datetime
from uuid import UUID

from ninja import Schema
from pydantic import Field

from workspace.schemas import UserRef


class PhaseIn(Schema):
    title: str = Field(min_length=1, max_length=200)
    start_at: date | None = None
    end_at: date | None = None


class PhasePatch(Schema):
    """Only the fields present in the body change; an explicit null clears start_at/end_at."""

    title: str | None = Field(None, min_length=1, max_length=200)
    start_at: date | None = None
    end_at: date | None = None
    active: bool | None = None


class ItemIn(Schema):
    """Create or update the plan row of a task; only the fields present change. A set `parent_task_id` nests the
    task under another planned task (and ignores the phase); `phase_id` null with no parent = top level."""

    phase_id: int | None = None
    parent_task_id: UUID | None = None
    start_at: date | None = None
    end_at: date | None = None
    position: int | None = Field(None, ge=0)
    active: bool | None = None


class LinkIn(Schema):
    predecessor_task_id: UUID
    successor_task_id: UUID


class ReorderItem(Schema):
    task_id: UUID
    phase_id: int | None = None
    parent_task_id: UUID | None = None


class ReorderIn(Schema):
    phase_ids: list[int] | None = None  # every active phase exactly once, in the new order
    items: list[ReorderItem] | None = None  # listed items take this order and placement


class PhaseOut(Schema):
    id: int
    wbs: str
    title: str
    position: int
    start_at: date | None  # own override
    end_at: date | None
    start: date | None  # effective: override, else the earliest task start
    end: date | None
    progress: int
    task_count: int
    active: bool = True


class ItemOut(Schema):
    task_id: UUID
    wbs: str
    level: int  # 1 = top level, 2 = under a phase or a parent, ...
    title: str
    status: str
    progress: int
    priority: str
    weight: int
    phase_id: int | None
    parent_task_id: UUID | None
    position: int
    start_at: date | None  # own plan dates
    end_at: date | None
    start: date | None  # effective: plan date, else the task's start / due date
    end: date | None
    owners: list[UserRef]


class LinkOut(Schema):
    id: int
    predecessor_task_id: UUID
    successor_task_id: UUID
    kind: str
    conflict: bool  # the successor is planned to start before the predecessor ends


class UnplannedOut(Schema):
    task_id: UUID
    title: str
    status: str
    progress: int
    start: date | None
    end: date | None


class ChartOut(Schema):
    project_id: UUID
    name: str
    role: str
    can_edit: bool
    start: date | None  # whole-chart range
    end: date | None
    phases: list[PhaseOut]
    items: list[ItemOut]  # WBS order (depth first, phases in order, then top-level tasks without a phase)
    links: list[LinkOut]
    unplanned: list[UnplannedOut]  # project tasks with no plan row yet


class PrintRow(Schema):
    kind: str  # phase | task
    wbs: str
    level: int
    title: str
    status: str
    progress: int
    start: date | None
    end: date | None
    owners: list[str]  # names


class PrintLink(Schema):
    from_wbs: str
    to_wbs: str
    conflict: bool


class PrintHoliday(Schema):
    date: date
    title: str


class PrintOut(Schema):
    project_id: UUID
    name: str
    generated_at: datetime
    start: date | None
    end: date | None
    days: int  # inclusive length of start..end
    weekend: list[int]  # 0 = Saturday
    holidays: list[PrintHoliday]
    progress: int  # project progress
    rows: list[PrintRow]
    links: list[PrintLink]
