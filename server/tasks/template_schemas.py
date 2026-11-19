from typing import Any, Literal
from uuid import UUID

from ninja import Field, Schema

from .schemas import MAX_CHECKLIST, MAX_PEOPLE, PRIORITY

Person = int | Literal["me"]  # a user id, or the person using the template


class TemplateData(Schema):
    title: str = Field(min_length=1, max_length=200)
    description: str = Field("", max_length=50_000)
    priority: str = Field("normal", pattern=PRIORITY)
    checklist: list[str] = Field(default_factory=list, max_length=MAX_CHECKLIST)
    label_ids: list[int] = Field(default_factory=list, max_length=200)
    relative_due_days: int | None = Field(None, ge=0, le=3650)  # due this many days after the task is created
    owners: list[Person] = Field(default_factory=list, max_length=MAX_PEOPLE)
    approvers: list[Person] = Field(default_factory=list, max_length=MAX_PEOPLE)
    followers: list[Person] = Field(default_factory=list, max_length=MAX_PEOPLE)


class TemplateIn(Schema):
    name: str = Field(min_length=1, max_length=100)
    scope: str = Field("personal", pattern="^(org|personal)$")
    data: TemplateData


class TemplatePatch(Schema):
    name: str | None = Field(None, min_length=1, max_length=100)
    data: TemplateData | None = None
    active: bool | None = None


class TemplateOut(Schema):
    id: int
    name: str
    scope: str
    owner_id: int | None
    data: TemplateData
    active: bool


class FromTemplateIn(Schema):
    template_id: int
    project_id: UUID | None = None
    column_id: int | None = None
    overrides: dict[str, Any] = Field(default_factory=dict)  # any TaskIn field except project_id / column_id
