"""The task views of a project: board (grouped by column), flat list, and calendar range."""
from datetime import datetime

from django.db.models import Exists, F, OuterRef, Q, QuerySet
from ninja.errors import HttpError

from accounts.models import User
from tasks.models import Task, TaskPerson
from tasks.queries import STATUS_VALUES
from tasks.serializers import briefs
from workspace.access import visible_labels
from workspace.models import SubjectLabel

from . import membership
from .models import BoardColumn, Project
from .schemas import ColumnTasks, ProjectTasksOut

VIEWS = ("board", "list", "calendar")
MAX_TASKS = 1000


def _filtered(user: User, project: Project, q: str, status: str, owner: int | None,
              label: int | None, include_hidden: bool = False) -> QuerySet[Task]:
    rows = Task.objects.filter(project=project).select_related("creator")
    if not (include_hidden and membership.role_in(user, project.pk) == membership.MANAGER):
        rows = rows.filter(hidden=False)
    wanted = {s for s in status.split(",") if s}
    if wanted:
        rows = rows.filter(status__in=wanted & STATUS_VALUES)
    if q.strip():
        rows = rows.filter(title__icontains=q.strip())
    if owner is not None:
        mine = TaskPerson.objects.filter(task=OuterRef("pk"), user_id=owner, role=TaskPerson.OWNER, active=True)
        rows = rows.filter(Exists(mine))
    if label is not None:
        ok = visible_labels(user).filter(pk=label, active=True).exists()
        subjects = SubjectLabel.objects.filter(label_id=label, active=True).values("subject_id") if ok else []
        rows = rows.filter(subject_id__in=subjects)
    return rows


def project_tasks(user: User, project: Project, view: str, start: datetime | None, end: datetime | None,
                  q: str = "", status: str = "", owner: int | None = None, label: int | None = None,
                  include_hidden: bool = False) -> ProjectTasksOut:
    if view not in VIEWS:
        raise HttpError(422, "view must be board, list or calendar")
    rows = _filtered(user, project, q, status, owner, label, include_hidden)
    if view == "calendar":
        if start is None or end is None or end <= start:
            raise HttpError(422, "calendar needs from and to (to after from)")
        rows = rows.filter(Q(due_at__gte=start, due_at__lt=end) | Q(start_at__gte=start, start_at__lt=end))
        ordered = rows.order_by(F("due_at").asc(nulls_last=True), "start_at", "id")
        return ProjectTasksOut(view=view, tasks=briefs(user, list(ordered[:MAX_TASKS])))
    if view == "list":
        ordered = rows.order_by(F("due_at").asc(nulls_last=True), "rank", "id")
        return ProjectTasksOut(view=view, tasks=briefs(user, list(ordered[:MAX_TASKS])))
    return _board(user, project, rows)


def _board(user: User, project: Project, rows: QuerySet[Task]) -> ProjectTasksOut:
    tasks = briefs(user, list(rows.filter(column__isnull=False).order_by("rank", "id")[:MAX_TASKS]))
    by_column: dict[int, list] = {}
    for brief in tasks:
        by_column.setdefault(brief.column_id, []).append(brief)
    columns = BoardColumn.objects.filter(project=project, active=True).order_by("rank", "id")
    return ProjectTasksOut(view="board", columns=[
        ColumnTasks(id=c.id, title=c.title, kind=c.kind, rank=c.rank, tasks=by_column.get(c.id, [])) for c in columns])
