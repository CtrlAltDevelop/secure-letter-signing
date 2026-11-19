"""Gantt API (mounted at /api, paths /projects/{id}/gantt/...). Rules in rules.py, writes in service.py."""
from uuid import UUID

from ninja import Router

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, user_of

from . import plan, printing, rules, service
from .models import GanttItem, GanttLink, GanttPhase
from .schemas import (ChartOut, ItemIn, ItemOut, LinkIn, LinkOut, PhaseIn, PhaseOut, PhasePatch, PrintOut, ReorderIn)

router = Router(tags=["gantt"], auth=BearerAuth())
ERRORS = {403: Detail, 404: Detail, 422: Detail}
BASE = "/projects/{uuid:project_id}/gantt"


def _chart(user, project_id: UUID) -> ChartOut:
    return plan.build(user, rules.visible(user, project_id))


@router.get(BASE, response={200: ChartOut, 404: Detail})
def chart(request, project_id: UUID):
    return _chart(user_of(request), project_id)


@router.get(BASE + "/print", response={200: PrintOut, 404: Detail})
def print_data(request, project_id: UUID):
    user = user_of(request)
    return printing.build(user, rules.visible(user, project_id))


def _phase(chart_out: ChartOut, phase: GanttPhase) -> PhaseOut:
    found = next((p for p in chart_out.phases if p.id == phase.pk), None)
    return found or PhaseOut(id=phase.pk, wbs="", title=phase.title, position=phase.position, start_at=phase.start_at,
                             end_at=phase.end_at, start=phase.start_at, end=phase.end_at, progress=0, task_count=0,
                             active=phase.active)


@router.post(BASE + "/phases", response={201: PhaseOut, **ERRORS})
def create_phase(request, project_id: UUID, data: PhaseIn):
    user = user_of(request)
    phase = service.create_phase(user, project_id, data)
    return 201, _phase(_chart(user, project_id), phase)


@router.patch(BASE + "/phases/{int:phase_id}", response={200: PhaseOut, **ERRORS})
def patch_phase(request, project_id: UUID, phase_id: int, data: PhasePatch):
    """Rename, set/clear dates, or `active: false` to switch it off (its tasks move to the top level)."""
    user = user_of(request)
    phase = service.patch_phase(user, project_id, phase_id, data)
    return _phase(_chart(user, project_id), phase)


@router.put(BASE + "/items/{uuid:task_id}", response={200: ItemOut, 404: Detail, 403: Detail, 422: Detail})
def upsert_item(request, project_id: UUID, task_id: UUID, data: ItemIn):
    """Put a task into the plan (or change its row). An inactive row comes back only if `active: true` is sent."""
    user = user_of(request)
    service.upsert_item(user, project_id, task_id, data)
    out = next((i for i in _chart(user, project_id).items if i.task_id == task_id), None)
    if out is None:  # switched off: not on the chart any more
        out = ItemOut(task_id=task_id, wbs="", level=0, title="", status="", progress=0, priority="", weight=1,
                      phase_id=None, parent_task_id=None, position=0, start_at=None, end_at=None, start=None,
                      end=None, owners=[])
    return out


@router.post(BASE + "/links", response={201: LinkOut, **ERRORS})
def add_link(request, project_id: UUID, data: LinkIn):
    """Finish-to-start dependency; 422 for self links, tasks of other projects and cycles. Idempotent."""
    user = user_of(request)
    link = service.add_link(user, project_id, data)
    return 201, next(x for x in _chart(user, project_id).links if x.id == link.pk)


@router.post(BASE + "/links/{int:link_id}/deactivate", response={200: Detail, **ERRORS})
def deactivate_link(request, project_id: UUID, link_id: int):
    service.deactivate_link(user_of(request), project_id, link_id)
    return {"detail": "Dependency switched off"}


@router.post(BASE + "/reorder", response={200: ChartOut, **ERRORS})
def reorder(request, project_id: UUID, data: ReorderIn):
    user = user_of(request)
    service.reorder(user, project_id, data)
    return _chart(user, project_id)
