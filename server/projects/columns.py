"""Board columns of a project: add, rename/retype/hide, reorder."""
from uuid import UUID

from django.db import transaction
from ninja.errors import HttpError

from accounts.models import User
from tasks.models import Task

from . import notices
from .models import BoardColumn
from .schemas import ColumnIn, ColumnOrder, ColumnPatch
from .service import RANK_GAP, lock_project


def active_columns(project_id):
    return BoardColumn.objects.filter(project_id=project_id, active=True).order_by("rank", "id")


@transaction.atomic
def add_column(user: User, project_id: UUID, data: ColumnIn) -> BoardColumn:
    project = lock_project(user, project_id, "edit")
    last = active_columns(project.pk).last()
    column = BoardColumn.objects.create(project=project, title=data.title.strip(), kind=data.kind,
                                        rank=(last.rank if last else 0) + RANK_GAP)
    notices.emit_project("project.updated", project, user, fields=["columns"])
    return column


def _hide(project_id, column: BoardColumn) -> None:
    if Task.objects.filter(column=column).exists():
        raise HttpError(409, "Move the tasks out of this column first")
    if active_columns(project_id).count() <= 1:
        raise HttpError(409, "A project needs at least one column")
    column.active = False


@transaction.atomic
def patch_column(user: User, project_id: UUID, column_id: int, data: ColumnPatch) -> BoardColumn:
    project = lock_project(user, project_id, "edit")
    column = BoardColumn.objects.select_for_update().filter(pk=column_id, project=project, active=True).first()
    if column is None:
        raise HttpError(404, "Not found")
    if data.active is False:
        _hide(project.pk, column)
    if data.title is not None:
        column.title = data.title.strip()
    if data.kind is not None:
        column.kind = data.kind
    column.save()
    notices.emit_project("project.updated", project, user, fields=["columns"])
    return column


@transaction.atomic
def reorder(user: User, project_id: UUID, data: ColumnOrder) -> None:
    project = lock_project(user, project_id, "edit")
    current = {c.id for c in active_columns(project.pk)}
    if sorted(data.ids) != sorted(current):
        raise HttpError(422, "ids must list every active column exactly once")
    for position, cid in enumerate(data.ids):
        BoardColumn.objects.filter(pk=cid).update(rank=(position + 1) * RANK_GAP)
    notices.emit_project("project.updated", project, user, fields=["columns"])
