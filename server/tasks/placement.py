"""Where a task lives: target checks, rank arithmetic inside a board column, and moving between projects/columns.

Ranks sit 65,536 apart; inserting between two neighbours takes the midpoint, and when there is no room the column is
renumbered, all under a `select_for_update` lock on the column row.
"""
from uuid import UUID

from django.db import transaction
from ninja.errors import HttpError

from accounts.models import User
from projects import membership, progress
from projects.models import BoardColumn, Project
from workspace import registry
from workspace.seen import mark_seen

from . import history, notices, rules, store
from .models import Task, TaskPerson
from .schemas import MoveIn

RANK_GAP = store.RANK_GAP


def target_project(user: User, project_id: UUID) -> Project:
    """The project to put a task into: 404 unless the user is in it, 403 for viewers, 409 when archived."""
    registry.require_module("projects")
    project = Project.objects.filter(pk=project_id).first()
    role = membership.role_in(user, project_id) if project else None
    if project is None or role is None:
        raise HttpError(404, "Not found")
    if role not in membership.CAN_WORK or (role == membership.MEMBER and not project.members_can_edit_tasks):
        raise HttpError(403, "Permission denied")
    if project.status == Project.ARCHIVED:
        raise HttpError(409, "The project is archived")
    return project


def default_column(project: Project) -> BoardColumn:
    columns = BoardColumn.objects.filter(project=project, active=True).order_by("rank", "id")
    column = columns.filter(kind=BoardColumn.TODO).first() or columns.first()
    if column is None:
        raise HttpError(422, "The project has no board column")
    return column


def resolve_target(user: User, project_id: UUID | None, column_id: int | None,
                   before: Task | None = None) -> tuple[Project | None, BoardColumn | None]:
    """Validated (project, column) for a task going there; (None, None) for a personal task."""
    if project_id is None:
        if column_id is not None or before is not None:
            raise HttpError(422, "column_id and before_id need a project_id")
        return None, None
    project = target_project(user, project_id)
    if column_id is not None:
        column = BoardColumn.objects.filter(pk=column_id, project=project, active=True).first()
        if column is None:
            raise HttpError(422, "Unknown column")
    elif before is not None and before.column_id and before.project_id == project.id:
        column = before.column
    else:
        column = default_column(project)
    if before is not None and before.column_id != column.id:
        raise HttpError(422, "before_id is not in the target column")
    return project, column


def check_people_in_project(project: Project, user_ids) -> None:
    """Everybody on a project task must be able to see it, so they must be active members."""
    missing = set(user_ids) - membership.member_ids(project.pk)
    if missing:
        raise HttpError(422, "Everyone on a project task must be a member of the project")


def active_person_ids(task: Task) -> set[int]:
    return set(TaskPerson.objects.filter(task=task, active=True).values_list("user_id", flat=True))


def _renumber(column: BoardColumn, siblings: list[Task], index: int) -> int:
    """Gaps everywhere again with a free slot at `index`; returns the rank of that slot."""
    for position, sibling in enumerate(siblings):
        sibling.rank = RANK_GAP * (position + 1 + (position >= index))
    Task.objects.bulk_update(siblings, ["rank"])
    return RANK_GAP * (index + 1)


def rank_for(column: BoardColumn, task_pk, before_id: UUID | None) -> int:
    """Rank for a task placed in `column` just before `before_id` (end when None). Call inside a transaction."""
    BoardColumn.objects.select_for_update().get(pk=column.pk)
    siblings = list(Task.objects.filter(column=column).exclude(pk=task_pk).order_by("rank", "id"))
    index = len(siblings)
    if before_id is not None:
        index = next((i for i, t in enumerate(siblings) if t.pk == before_id), -1)
        if index < 0:
            raise HttpError(422, "before_id is not in the target column")
    below = siblings[index - 1].rank if index > 0 else 0
    if index == len(siblings):
        return below + RANK_GAP
    above = siblings[index].rank
    middle = (below + above) // 2
    return middle if below < middle < above else _renumber(column, siblings, index)


def _ids(project_id, column_id) -> dict:
    return {"project": str(project_id) if project_id else None, "column": column_id}


def move_locked(user: User, task: Task, data: MoveIn) -> Task:
    """Move a locked task: edit rights in the source (checked here), member rights in the target."""
    store.require(user, task, "move")
    before = Task.objects.select_related("column").filter(pk=data.before_id).first() if data.before_id else None
    if data.before_id and before is None:
        raise HttpError(422, "Unknown before_id")
    project, column = resolve_target(user, data.project_id, data.column_id, before)
    if project and project.id != task.project_id:
        check_people_in_project(project, active_person_ids(task))
    old_project, old_column, audience_before = task.project_id, task.column_id, rules.audience(task)
    task.project, task.column = project, column
    task.rank = rank_for(column, task.pk, data.before_id) if column else 0
    task.version += 1
    store.save(task)
    if old_project != task.project_id:
        progress.recompute(old_project)
        history.log(task.subject, user, "project", str(old_project) if old_project else None,
                    str(task.project_id) if task.project_id else None)
    if old_column != task.column_id:
        history.log(task.subject, user, "column", old_column, task.column_id)
    notices.emit_task("task.moved", task, user, extra_recipients=audience_before,
                      from_project_id=str(old_project) if old_project else None, from_column_id=old_column,
                      to_project_id=str(task.project_id) if task.project_id else None, to_column_id=task.column_id)
    mark_seen(user, task.subject)
    return task


@transaction.atomic
def move(user: User, task_id: UUID, data: MoveIn) -> Task:
    return move_locked(user, store.lock_task(user, task_id), data)
