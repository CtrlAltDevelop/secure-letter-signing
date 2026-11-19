"""My done-list for one Tehran-local day: what I completed, submitted for approval, approved or rejected."""
from datetime import date, timedelta

from accounts.models import User
from workspace.models import ChangeHistory
from workspace.work_calendar import day_start

from .models import Task
from .queries import visible_tasks

GROUPS = ("completed", "submitted", "approved", "rejected")


def _action(row: ChangeHistory) -> str | None:
    if row.field == "status":
        return {Task.DONE: "completed", Task.AWAITING: "submitted"}.get(row.new)
    new = row.new if isinstance(row.new, dict) else {}
    if row.field == "decision" and new.get("user_id") == row.actor_id:
        return {"approved": "approved", "rejected": "rejected"}.get(new.get("decision"))
    return None


def done_on(user: User, day: date) -> dict:
    """Entries come from the task history (actor = me) so reopened and re-completed tasks show every time."""
    start, end = day_start(day), day_start(day + timedelta(days=1))
    rows = list(ChangeHistory.objects.filter(actor=user, field__in=("status", "decision"), at__gte=start, at__lt=end,
                                             subject__task__isnull=False).order_by("at", "id"))
    tasks = {t.subject_id: t for t in visible_tasks(user).filter(subject_id__in={r.subject_id for r in rows},
                                                                  hidden=False).select_related("project")}
    groups: dict[str, list[dict]] = {g: [] for g in GROUPS}
    for row in rows:
        action, task = _action(row), tasks.get(row.subject_id)
        if action and task:
            groups[action].append({"task_id": str(task.id), "subject_id": str(task.subject_id), "title": task.title,
                                   "project_id": str(task.project_id) if task.project_id else None,
                                   "project_name": task.project.name if task.project_id else "", "at": row.at})
    return {"date": day, "groups": groups, "total": sum(len(v) for v in groups.values())}
