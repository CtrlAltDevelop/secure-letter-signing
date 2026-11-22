"""Read side: the whole chart of a project (WBS codes, effective dates, progress) built from plain rows."""
from datetime import date

from accounts.models import User
from projects import membership
from projects.models import Project
from tasks.models import Task, TaskPerson
from workspace.schemas import user_ref

from . import critical, rules
from .models import GanttItem, GanttLink, GanttPhase
from .schemas import ChartOut, ItemOut, LinkOut, PhaseOut, UnplannedOut

MAX_UNPLANNED = 500


def _day(value) -> date | None:
    return value.date() if value else None


def effective(item: GanttItem) -> tuple[date | None, date | None]:
    """Plan dates, falling back to the task's own start and due dates."""
    return item.start_at or _day(item.task.start_at), item.end_at or _day(item.task.due_at)


def average(tasks: list[Task]) -> int:
    live = [t for t in tasks if t.status != Task.CANCELLED]
    total = sum(t.weight for t in live)
    return round(sum(t.progress * t.weight for t in live) / total) if total else 0


def _span(dates: list[tuple[date | None, date | None]]) -> tuple[date | None, date | None]:
    starts = [s for s, _ in dates if s]
    ends = [e for _, e in dates if e]
    return (min(starts) if starts else None), (max(ends) if ends else None)


def planned_items(project: Project, include_hidden: bool) -> list[GanttItem]:
    rows = GanttItem.objects.filter(project=project, active=True).select_related("task")
    return list(rows if include_hidden else rows.filter(task__hidden=False))


def _owners(tasks: list[Task]) -> dict:
    rows = TaskPerson.objects.filter(task__in=tasks, role=TaskPerson.OWNER, active=True).select_related(
        "user", "user__org_title").order_by("position", "id")
    out: dict = {}
    for row in rows:
        out.setdefault(row.task_id, []).append(row.user)
    return out


def _order(rows, key=lambda r: (r.position, r.pk)):
    return sorted(rows, key=key)


def build(user: User, project: Project) -> ChartOut:
    role = membership.role_in(user, project.pk) or ""
    include_hidden = role == membership.MANAGER
    phases = _order(GanttPhase.objects.filter(project=project, active=True))
    items = planned_items(project, include_hidden)
    by_task = {i.task_id: i for i in items}
    children: dict = {}
    roots: dict = {}  # phase id (or None) -> root items
    for item in items:
        if item.parent_id and item.parent_id in {i.pk for i in items}:
            children.setdefault(item.parent_id, []).append(item)
        else:
            roots.setdefault(item.phase_id, []).append(item)
    owners = _owners([i.task for i in items])
    out_items: list[ItemOut] = []
    wbs_of: dict = {}
    phase_items: dict = {}

    def walk(item: GanttItem, code: str, level: int, phase_id, parent: GanttItem | None) -> None:
        start, end = effective(item)
        wbs_of[item.task_id] = code
        phase_items.setdefault(phase_id, []).append(item)
        t = item.task
        out_items.append(ItemOut(
            task_id=t.id, wbs=code, level=level, title=t.title, status=t.status, progress=t.progress,
            priority=t.priority, weight=t.weight, phase_id=phase_id, parent_task_id=parent.task_id if parent else None,
            position=item.position, start_at=item.start_at, end_at=item.end_at, start=start, end=end,
            owners=[user_ref(u) for u in owners.get(t.id, [])]))
        for n, child in enumerate(_order(children.get(item.pk, [])), 1):
            walk(child, f"{code}.{n}", level + 1, phase_id, item)

    phase_outs: list[PhaseOut] = []
    for i, phase in enumerate(phases, 1):
        for n, item in enumerate(_order(roots.get(phase.pk, [])), 1):
            walk(item, f"{i}.{n}", 2, phase.pk, None)
        mine = phase_items.get(phase.pk, [])
        start, end = _span([effective(x) for x in mine])
        phase_outs.append(PhaseOut(
            id=phase.pk, wbs=str(i), title=phase.title, position=phase.position, start_at=phase.start_at,
            end_at=phase.end_at, start=phase.start_at or start, end=phase.end_at or end,
            progress=average([x.task for x in mine]), task_count=len(mine)))
    for n, item in enumerate(_order(roots.get(None, [])), 1):
        walk(item, str(len(phases) + n), 1, None, None)

    links = [LinkOut(id=lk.pk, predecessor_task_id=lk.predecessor_id, successor_task_id=lk.successor_id, kind=lk.kind,
                     conflict=_conflict(by_task, lk))
             for lk in GanttLink.objects.filter(project=project, active=True).order_by("id")
             if lk.predecessor_id in by_task and lk.successor_id in by_task]
    _mark_critical(out_items, links)
    start, end = _span([(p.start, p.end) for p in phase_outs] + [(i.start, i.end) for i in out_items])
    return ChartOut(project_id=project.pk, name=project.name, role=role, can_edit=rules.can_edit(user, project),
                    start=start, end=end, phases=phase_outs, items=out_items, links=links,
                    unplanned=_unplanned(project, by_task, include_hidden))


def _mark_critical(items: list[ItemOut], links: list[LinkOut]) -> None:
    """Durations are inclusive days between the effective dates (1 when undated)."""
    days = {i.task_id: (i.end - i.start).days + 1 if i.start and i.end and i.end >= i.start else 1 for i in items}
    spare = critical.slack(days, [(lk.predecessor_task_id, lk.successor_task_id) for lk in links])
    for i in items:
        if i.task_id in spare:
            i.slack, i.critical = spare[i.task_id], spare[i.task_id] == 0


def _conflict(by_task: dict, link: GanttLink) -> bool:
    _, pred_end = effective(by_task[link.predecessor_id])
    succ_start, _ = effective(by_task[link.successor_id])
    return bool(pred_end and succ_start and succ_start < pred_end)


def _unplanned(project: Project, planned: dict, include_hidden: bool) -> list[UnplannedOut]:
    rows = Task.objects.filter(project=project).exclude(status=Task.CANCELLED).exclude(pk__in=list(planned))
    if not include_hidden:
        rows = rows.filter(hidden=False)
    return [UnplannedOut(task_id=t.id, title=t.title, status=t.status, progress=t.progress,
                         start=_day(t.start_at), end=_day(t.due_at))
            for t in rows.order_by("created_at", "id")[:MAX_UNPLANNED]]
