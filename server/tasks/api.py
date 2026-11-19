"""Tasks API (mounted at /api/tasks). Rules live in rules.py, state changes in service/workflow/checklist."""
from datetime import datetime
from uuid import UUID

from django.shortcuts import get_object_or_404
from ninja import Router
from ninja.errors import HttpError

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, user_of
from accounts.models import User
from workspace import registry
from workspace.seen import mark_seen

from . import checklist, copying, placement, queries, removal, rules, service, workflow
from .models import Task
from .schemas import (ChecklistAdd, ChecklistOrder, ChecklistPatch, CopyIn, DecisionIn, MoveIn, NoteIn, PeopleIn,
                      RemovalDecisionIn, RemovalNoteIn, TaskBrief, TaskIn, TaskOut, TaskPatch)
from .api_daily import router as daily_router
from .serializers import briefs, task_out

router = Router(tags=["tasks"], auth=BearerAuth())
ERRORS = {403: Detail, 404: Detail, 409: Detail, 422: Detail}
router.add_router("", daily_router)  # /tasks/done-daily


def _gate() -> None:
    registry.require_module("tasks")


def _visible(user: User, task_id: UUID) -> Task:
    task = get_object_or_404(Task.objects.select_related("subject", "creator"), pk=task_id)
    if not rules.can(user, task, "see"):
        raise HttpError(404, "Not found")
    return task


def _out(user: User, task: Task) -> TaskOut:
    task = Task.objects.select_related("subject", "creator").get(pk=task.pk)
    return task_out(user, task)


@router.post("", response={201: TaskOut, **ERRORS})
def create(request, data: TaskIn):
    _gate()
    user = user_of(request)
    if not user.has_grant("task.create"):
        raise HttpError(403, "Permission denied")
    return 201, _out(user, service.create_task(user, data))


@router.get("", response=list[TaskBrief])
def list_tasks(request, box: str = "all", status: str = "", q: str = "", label: int | None = None,
               due_before: datetime | None = None, customer: UUID | None = None, include_hidden: bool = False,
               limit: int = 50, offset: int = 0):
    _gate()
    user = user_of(request)
    if box not in ("inbox", "followup", "all"):
        raise HttpError(422, "box must be inbox, followup or all")
    start = max(offset, 0)
    rows = queries.filtered(user, box, status, q, label, due_before, customer, include_hidden)
    page = list(rows.select_related("creator")[start : start + max(min(limit, queries.MAX_LIMIT), 0)])
    return briefs(user, page)


@router.get("/{uuid:task_id}", response={200: TaskOut, 404: Detail})
def get_task(request, task_id: UUID):
    _gate()
    user = user_of(request)
    return _out(user, _visible(user, task_id))


@router.post("/{uuid:task_id}/seen", response={204: None, 404: Detail})
def seen(request, task_id: UUID):
    _gate()
    user = user_of(request)
    mark_seen(user, _visible(user, task_id).subject)
    return 204, None


@router.patch("/{uuid:task_id}", response={200: TaskOut, **ERRORS})
def patch(request, task_id: UUID, data: TaskPatch):
    _gate()
    user = user_of(request)
    return _out(user, service.update_task(user, task_id, data))


@router.put("/{uuid:task_id}/people", response={200: TaskOut, **ERRORS})
def put_people(request, task_id: UUID, data: PeopleIn):
    _gate()
    user = user_of(request)
    return _out(user, service.set_people(user, task_id, data))


@router.post("/{uuid:task_id}/checklist", response={200: TaskOut, **ERRORS})
def checklist_add(request, task_id: UUID, data: ChecklistAdd):
    _gate()
    user = user_of(request)
    return _out(user, checklist.add_item(user, task_id, data))


@router.put("/{uuid:task_id}/checklist/order", response={200: TaskOut, **ERRORS})
def checklist_order(request, task_id: UUID, data: ChecklistOrder):
    _gate()
    user = user_of(request)
    return _out(user, checklist.reorder(user, task_id, data))


@router.patch("/{uuid:task_id}/checklist/{int:item_id}", response={200: TaskOut, **ERRORS})
def checklist_patch(request, task_id: UUID, item_id: int, data: ChecklistPatch):
    _gate()
    user = user_of(request)
    return _out(user, checklist.patch_item(user, task_id, item_id, data))


@router.post("/{uuid:task_id}/complete", response={200: TaskOut, **ERRORS})
def complete(request, task_id: UUID, data: NoteIn | None = None):
    _gate()
    user = user_of(request)
    return _out(user, workflow.complete(user, task_id, data.note if data else ""))


@router.post("/{uuid:task_id}/decision", response={200: TaskOut, **ERRORS})
def decision(request, task_id: UUID, data: DecisionIn):
    _gate()
    user = user_of(request)
    return _out(user, workflow.decide(user, task_id, data.decision, data.note))


@router.post("/{uuid:task_id}/reopen", response={200: TaskOut, **ERRORS})
def reopen(request, task_id: UUID):
    _gate()
    user = user_of(request)
    return _out(user, workflow.reopen(user, task_id))


@router.post("/{uuid:task_id}/cancel", response={200: TaskOut, **ERRORS})
def cancel(request, task_id: UUID):
    _gate()
    user = user_of(request)
    return _out(user, workflow.cancel(user, task_id))


@router.post("/{uuid:task_id}/removal-request", response={200: TaskOut, **ERRORS})
def removal_request(request, task_id: UUID, data: RemovalNoteIn | None = None):
    _gate()
    user = user_of(request)
    return _out(user, removal.request_removal(user, task_id, data.note if data else ""))


@router.post("/{uuid:task_id}/removal-decision", response={200: TaskOut, **ERRORS})
def removal_decision(request, task_id: UUID, data: RemovalDecisionIn):
    _gate()
    user = user_of(request)
    return _out(user, removal.decide_removal(user, task_id, data.decision, data.note))


@router.post("/{uuid:task_id}/move", response={200: TaskOut, **ERRORS})
def move(request, task_id: UUID, data: MoveIn):
    _gate()
    user = user_of(request)
    return _out(user, placement.move(user, task_id, data))


@router.post("/{uuid:task_id}/copy", response={201: TaskOut, **ERRORS})
def copy(request, task_id: UUID, data: CopyIn | None = None):
    _gate()
    user = user_of(request)
    return 201, _out(user, copying.copy_task(user, task_id, data.project_id if data else None))
