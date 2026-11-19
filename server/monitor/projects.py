"""`GET /monitor/projects`: per project and per project group. Counts, dates and plaintext names only."""
from django.db.models import Count, Max, Q
from django.utils import timezone

from projects.models import Project
from tasks.models import Task

SORTS = ("last_done", "most_overdue", "least_overdue", "completed")


def _task_stats() -> dict:
    now = timezone.now()
    active = Q(status__in=(Task.OPEN, Task.AWAITING))
    rows = (Task.objects.filter(hidden=False, project__isnull=False).exclude(status=Task.CANCELLED).order_by()
            .values("project_id")
            .annotate(open=Count("pk", filter=active), done=Count("pk", filter=Q(status=Task.DONE)),
                      overdue=Count("pk", filter=active & Q(due_at__lt=now)),
                      last_done_at=Max("completed_at", filter=Q(status=Task.DONE))))
    return {r["project_id"]: r for r in rows}


def _row(project: Project, stats: dict) -> dict:
    s = stats.get(project.id) or {"open": 0, "done": 0, "overdue": 0, "last_done_at": None}
    return {"id": str(project.id), "name": project.name, "status": project.status, "progress": project.progress,
            "group_id": project.group_id, "group_name": project.group.name if project.group_id else "",
            "tasks_open": s["open"], "tasks_done": s["done"], "tasks_overdue": s["overdue"],
            "last_done_at": s["last_done_at"]}


def _group_rows(rows: list[dict]) -> list[dict]:
    groups: dict = {}
    for r in rows:
        g = groups.setdefault(r["group_id"], {"group_id": r["group_id"], "group_name": r["group_name"], "projects": 0,
                                              "tasks_open": 0, "tasks_done": 0, "tasks_overdue": 0,
                                              "last_done_at": None})
        g["projects"] += 1
        for k in ("tasks_open", "tasks_done", "tasks_overdue"):
            g[k] += r[k]
        if r["last_done_at"] and (g["last_done_at"] is None or r["last_done_at"] > g["last_done_at"]):
            g["last_done_at"] = r["last_done_at"]
    return list(groups.values())


def _sort(rows: list[dict], sort: str, done_key: str) -> list[dict]:
    epoch = timezone.now().min
    if sort == "last_done":
        return sorted(rows, key=lambda r: r["last_done_at"] or epoch, reverse=True)
    if sort == "completed":
        return sorted(rows, key=lambda r: r[done_key], reverse=True)
    return sorted(rows, key=lambda r: r["tasks_overdue"], reverse=sort == "most_overdue")


def report(sort: str, include_archived: bool) -> dict:
    stats = _task_stats()
    qs = Project.objects.select_related("group")
    if not include_archived:
        qs = qs.exclude(status=Project.ARCHIVED)
    rows = [_row(p, stats) for p in qs.order_by("id")]
    return {"sort": sort, "projects": _sort(rows, sort, "tasks_done"),
            "groups": _sort(_group_rows(rows), sort, "tasks_done")}
