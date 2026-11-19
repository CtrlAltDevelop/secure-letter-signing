"""Task templates: organisation-wide (manager only) or personal. Never deleted, only deactivated.

The stored `data` keeps the description encrypted; everything else is plain JSON.
"""
from datetime import timedelta
from uuid import UUID

from django.db.models import Q, QuerySet
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja.errors import HttpError
from pydantic import ValidationError

from accounts.models import User
from projects import membership
from workspace.access import visible_labels
from workspace.models import Label
from workspace.textbox import open_text, seal_text

from . import service
from .models import Task, TaskTemplate
from .schemas import TaskIn
from .template_schemas import FromTemplateIn, TemplateData, TemplateIn, TemplateOut, TemplatePatch

RESERVED_OVERRIDES = {"project_id", "column_id"}
MAX_ITEM = 300


def visible(user: User) -> QuerySet[TaskTemplate]:
    return TaskTemplate.objects.filter(Q(owner__isnull=True) | Q(owner=user))


def _data_out(stored: dict) -> TemplateData:
    return TemplateData(**{**stored, "description": open_text(stored.get("description") or {})})


def out(t: TaskTemplate) -> TemplateOut:
    return TemplateOut(id=t.id, name=t.name, scope="personal" if t.owner_id else "org", owner_id=t.owner_id,
                       data=_data_out(t.data), active=t.active)


def _stored(data: TemplateData) -> dict:
    dump = data.model_dump()
    dump["description"] = seal_text(data.description)
    dump["checklist"] = [c.strip() for c in data.checklist]
    return dump


def _check(user: User, org: bool, data: TemplateData) -> None:
    if not all(0 < len(c.strip()) <= MAX_ITEM for c in data.checklist):
        raise HttpError(422, "Checklist items must be 1-300 characters")
    ids = {p for p in (*data.owners, *data.approvers, *data.followers) if p != "me"}
    if User.objects.filter(pk__in=ids, is_active=True).count() != len(ids):
        raise HttpError(422, "Unknown or inactive user in the template")
    wanted = set(data.label_ids)
    allowed = Label.objects.filter(scope=Label.ORG) if org else visible_labels(user)
    if allowed.filter(pk__in=wanted, active=True).count() != len(wanted):
        raise HttpError(422, "Unknown or inactive label in the template")


def create(user: User, data: TemplateIn) -> TaskTemplate:
    if data.scope == "org" and not user.is_manager:
        raise HttpError(403, "Only the manager can create organisation templates")
    _check(user, data.scope == "org", data.data)
    return TaskTemplate.objects.create(owner=user if data.scope == "personal" else None, name=data.name.strip(),
                                       data=_stored(data.data))


def update(user: User, template_id: int, data: TemplatePatch) -> TaskTemplate:
    template = get_object_or_404(visible(user), pk=template_id)
    if template.owner_id is None and not user.is_manager:
        raise HttpError(403, "Only the manager can change organisation templates")
    if data.name is not None:
        template.name = data.name.strip()
    if data.data is not None:
        _check(user, template.owner_id is None, data.data)
        template.data = _stored(data.data)
    if data.active is not None:
        template.active = data.active
    template.save()
    return template


def _people(user: User, raw: list, allowed: set[int] | None) -> list[int]:
    """Template people for this user: 'me' resolved, inactive users and non project members dropped."""
    ids = list(dict.fromkeys(user.id if p == "me" else p for p in raw))
    live = set(User.objects.filter(pk__in=ids, is_active=True).values_list("pk", flat=True))
    return [i for i in ids if i in live and (allowed is None or i in allowed)]


def _base_input(user: User, template: TaskTemplate, project_id: UUID | None) -> dict:
    d = template.data
    allowed = membership.member_ids(project_id) if project_id else None
    labels = visible_labels(user).filter(pk__in=d.get("label_ids", []), active=True).values_list("pk", flat=True)
    days = d.get("relative_due_days")
    return {
        "title": d["title"], "description": {"text": open_text(d.get("description") or {})},
        "priority": d.get("priority", "normal"), "checklist": list(d.get("checklist", [])),
        "label_ids": sorted(labels), "owner_ids": _people(user, d.get("owners", []), allowed),
        "approver_ids": _people(user, d.get("approvers", []), allowed),
        "follower_ids": _people(user, d.get("followers", []), allowed),
        "due_at": (timezone.now() + timedelta(days=days)).isoformat() if days is not None else None,
    }


def build_input(user: User, data: FromTemplateIn) -> TaskIn:
    template = get_object_or_404(visible(user), pk=data.template_id)
    if not template.active:
        raise HttpError(422, "The template is inactive")
    unknown = (set(data.overrides) - set(TaskIn.model_fields)) | (set(data.overrides) & RESERVED_OVERRIDES)
    if unknown:
        raise HttpError(422, f"Cannot override: {', '.join(sorted(unknown))}")
    merged = {**_base_input(user, template, data.project_id), **data.overrides,
              "project_id": data.project_id, "column_id": data.column_id}
    try:
        return TaskIn.model_validate(merged)
    except ValidationError as exc:
        problems = "; ".join(f"{'.'.join(map(str, e['loc']))} {e['msg']}" for e in exc.errors())
        raise HttpError(422, f"Invalid override: {problems}") from exc


def create_from_template(user: User, data: FromTemplateIn) -> Task:
    if not user.has_grant("task.create"):
        raise HttpError(403, "Permission denied")
    return service.create_task(user, build_input(user, data))
