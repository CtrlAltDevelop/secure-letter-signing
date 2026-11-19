"""Write side of the Gantt plan. Every call locks the project, checks `rules.editable`, logs ChangeHistory, writes an
audit row with ids only and tells the other members live. Nothing is deleted: phases, items and links are switched off."""
from uuid import UUID

from django.db import transaction
from django.db.models import Max
from django.shortcuts import get_object_or_404
from ninja.errors import HttpError

from accounts.models import User, audit
from projects import membership
from projects.models import Project
from tasks.models import Task
from workspace import changes
from workspace.events import emit

from . import readiness, rules
from .models import GanttItem, GanttLink, GanttPhase
from .schemas import ItemIn, LinkIn, PhaseIn, PhasePatch, ReorderIn

MODULE = "gantt"
MAX_DEPTH = 5  # nesting levels below a phase / the top


def _changed(user: User, project: Project, what: str, ident: str, old=None, new=None) -> None:
    changes.log(project.subject, user, f"gantt.{what}", old, new)
    audit(user, f"gantt_{what}", ident, project=str(project.id))
    emit(MODULE, "gantt.updated", project.subject, project.name, user, membership.member_ids(project.pk) - {user.id},
         object_id=str(project.id), what=what)


def _check_dates(start, end) -> None:
    if start and end and end < start:
        raise HttpError(422, "The end date is before the start date")


# ---- phases -------------------------------------------------------------------------------------------------------

def _clean_title(title: str) -> str:
    title = " ".join(title.split())
    if not title:
        raise HttpError(422, "Title is required")
    return title


@transaction.atomic
def create_phase(user: User, project_id: UUID, data: PhaseIn) -> GanttPhase:
    project = rules.editable(user, project_id)
    _check_dates(data.start_at, data.end_at)
    last = GanttPhase.objects.filter(project=project).aggregate(m=Max("position"))["m"]
    phase = GanttPhase.objects.create(project=project, title=_clean_title(data.title), start_at=data.start_at,
                                      end_at=data.end_at, position=0 if last is None else last + 1)
    _changed(user, project, "phase_created", str(phase.pk), None, {"id": phase.pk})
    return phase


@transaction.atomic
def patch_phase(user: User, project_id: UUID, phase_id: int, data: PhasePatch) -> GanttPhase:
    project = rules.editable(user, project_id)
    phase = get_object_or_404(GanttPhase.objects.select_for_update(), pk=phase_id, project=project)
    given = data.model_dump(exclude_unset=True)
    if "title" in given and given["title"] is not None:
        phase.title = _clean_title(given["title"])
    for field in ("start_at", "end_at"):
        if field in given:
            setattr(phase, field, given[field])
    _check_dates(phase.start_at, phase.end_at)
    if given.get("active") is not None and given["active"] != phase.active:
        phase.active = given["active"]
        if not phase.active:  # its tasks stay in the plan, at the top level
            GanttItem.objects.filter(phase=phase).update(phase=None)
        else:
            phase.position = (GanttPhase.objects.filter(project=project).aggregate(m=Max("position"))["m"] or 0) + 1
    phase.save()
    _changed(user, project, "phase_changed", str(phase.pk), None, {"fields": sorted(given)})
    return phase


# ---- items --------------------------------------------------------------------------------------------------------

def _project_task(project: Project, task_id: UUID, user: User) -> Task:
    task = Task.objects.filter(pk=task_id, project=project).first()
    if task is None or (task.hidden and membership.role_in(user, project.pk) != membership.MANAGER):
        raise HttpError(422, "The task does not belong to this project")
    return task


def _depth(item: GanttItem | None) -> int:
    depth = 0
    while item is not None and depth <= MAX_DEPTH + 1:
        depth, item = depth + 1, item.parent
    return depth


def _is_descendant(candidate: GanttItem, item: GanttItem) -> bool:
    node = candidate
    while node is not None:
        if node.pk == item.pk:
            return True
        node = node.parent
    return False


def _place(project: Project, item: GanttItem, phase_id: int | None, parent_task_id: UUID | None) -> None:
    """Set where `item` sits: under a parent (phase follows the parent's root) or at the top, in a phase or not."""
    if phase_id is not None and parent_task_id is not None:
        raise HttpError(422, "Give either a phase or a parent task, not both")
    if parent_task_id is not None:
        parent = GanttItem.objects.filter(project=project, task_id=parent_task_id, active=True).select_related(
            "parent").first()
        if parent is None:
            raise HttpError(422, "The parent task is not in the plan")
        if item.pk and _is_descendant(parent, item):
            raise HttpError(422, "A task cannot be nested under itself")
        if _depth(parent) >= MAX_DEPTH:
            raise HttpError(422, "The plan is nested too deeply")
        item.parent, item.phase = parent, None
        return
    if phase_id is not None and not GanttPhase.objects.filter(pk=phase_id, project=project, active=True).exists():
        raise HttpError(422, "Unknown phase")
    item.parent, item.phase_id = None, phase_id


def _next_position(project: Project, item: GanttItem) -> int:
    siblings = GanttItem.objects.filter(project=project, parent=item.parent, phase=item.phase)
    last = siblings.aggregate(m=Max("position"))["m"]
    return 0 if last is None else last + 1


@transaction.atomic
def upsert_item(user: User, project_id: UUID, task_id: UUID, data: ItemIn) -> GanttItem:
    project = rules.editable(user, project_id)
    task = _project_task(project, task_id, user)
    given = data.model_dump(exclude_unset=True)
    item = GanttItem.objects.select_for_update().filter(task=task).select_related("parent").first()
    created = item is None
    item = item or GanttItem(task=task, project=project)
    if "phase_id" in given or "parent_task_id" in given or created:
        _place(project, item, given.get("phase_id"), given.get("parent_task_id"))
        if not created:
            item.position = _next_position(project, item)
    for field in ("start_at", "end_at"):
        if field in given:
            setattr(item, field, given[field])
    _check_dates(item.start_at, item.end_at)
    if created or "position" in given and given["position"] is not None:
        item.position = given.get("position") if given.get("position") is not None else _next_position(project, item)
    was_active = item.active
    if given.get("active") is not None:
        item.active = given["active"]
    item.save()
    if was_active and not item.active:
        _detach(item)
    _changed(user, project, "item_created" if created else "item_changed", str(task.id), None, {"fields": sorted(given)})
    return item


def _detach(item: GanttItem) -> None:
    """A switched-off item hands its children to its own parent/phase and drops its links."""
    for child in item.children.all():
        child.parent, child.phase = item.parent, item.phase
        child.save(update_fields=["parent", "phase"])
    for link in GanttLink.objects.filter(active=True, predecessor=item.task) | GanttLink.objects.filter(
            active=True, successor=item.task):
        link.active = False
        link.save(update_fields=["active"])
        readiness.check(link.successor)


# ---- links --------------------------------------------------------------------------------------------------------

def _reaches(start: UUID, goal: UUID, project: Project) -> bool:
    """True when `goal` can be reached from `start` following active links predecessor -> successor."""
    edges: dict = {}
    for pred, succ in GanttLink.objects.filter(project=project, active=True).values_list("predecessor_id", "successor_id"):
        edges.setdefault(pred, []).append(succ)
    seen, todo = set(), [start]
    while todo:
        node = todo.pop()
        if node == goal:
            return True
        if node not in seen:
            seen.add(node)
            todo.extend(edges.get(node, []))
    return False


def _ensure_item(project: Project, task: Task) -> None:
    item, created = GanttItem.objects.get_or_create(task=task, defaults={"project": project})
    if created:
        item.position = _next_position(project, item)
        item.save(update_fields=["position"])
    elif not item.active:
        item.active = True
        item.parent = item.phase = None
        item.position = _next_position(project, item)
        item.save()


@transaction.atomic
def add_link(user: User, project_id: UUID, data: LinkIn) -> GanttLink:
    project = rules.editable(user, project_id)
    if data.predecessor_task_id == data.successor_task_id:
        raise HttpError(422, "A task cannot depend on itself")
    pred = _project_task(project, data.predecessor_task_id, user)
    succ = _project_task(project, data.successor_task_id, user)
    link = GanttLink.objects.filter(predecessor=pred, successor=succ).first()
    if link is not None and link.active:
        return link
    if _reaches(succ.pk, pred.pk, project):
        raise HttpError(422, "This dependency would create a cycle")
    _ensure_item(project, pred)
    _ensure_item(project, succ)
    if link is None:
        link = GanttLink.objects.create(project=project, predecessor=pred, successor=succ, created_by=user)
    else:
        link.active = True
        link.save(update_fields=["active"])
    GanttItem.objects.filter(task=succ).update(ready_notified_at=None)
    _changed(user, project, "link_added", str(link.pk), None, {"from": str(pred.id), "to": str(succ.id)})
    return link


@transaction.atomic
def deactivate_link(user: User, project_id: UUID, link_id: int) -> GanttLink:
    project = rules.editable(user, project_id)
    link = get_object_or_404(GanttLink.objects.select_related("successor"), pk=link_id, project=project)
    if link.active:
        link.active = False
        link.save(update_fields=["active"])
        _changed(user, project, "link_removed", str(link.pk), {"from": str(link.predecessor_id),
                                                              "to": str(link.successor_id)}, None)
        readiness.check(link.successor)
    return link


# ---- reorder ------------------------------------------------------------------------------------------------------

@transaction.atomic
def reorder(user: User, project_id: UUID, data: ReorderIn) -> None:
    project = rules.editable(user, project_id)
    if data.phase_ids is not None:
        active = set(GanttPhase.objects.filter(project=project, active=True).values_list("pk", flat=True))
        if sorted(data.phase_ids) != sorted(active):
            raise HttpError(422, "phase_ids must list every active phase exactly once")
        for position, pk in enumerate(data.phase_ids):
            GanttPhase.objects.filter(pk=pk).update(position=position)
    if data.items is not None:
        tasks = [i.task_id for i in data.items]
        if len(set(tasks)) != len(tasks):
            raise HttpError(422, "A task is listed twice")
        rows = {i.task_id: i for i in GanttItem.objects.select_for_update().filter(
            project=project, active=True, task_id__in=tasks).select_related("parent")}
        if len(rows) != len(tasks):
            raise HttpError(422, "A listed task is not in the plan")
        for position, entry in enumerate(data.items):
            item = rows[entry.task_id]
            _place(project, item, entry.phase_id, entry.parent_task_id)
            item.position = position
            item.save(update_fields=["parent", "phase", "position"])
    _changed(user, project, "reordered", str(project.id))
