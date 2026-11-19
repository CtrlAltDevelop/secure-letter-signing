"""`POST /projects/{id}/copy`: a new project with the same settings, columns, members and (non-removed) tasks.

Tasks are copied like `tasks.copying` copies one task (fresh open task, same people when they are members of the new
project, checklist, labels, shared file blobs). The caller becomes owner and manager of the copy.
"""
from uuid import UUID

from django.db import transaction
from ninja.errors import HttpError

from accounts.models import User, audit
from tasks import copying as task_copying
from tasks import history
from tasks.models import Task
from workspace.models import Subject
from workspace.seen import mark_seen

from . import membership, notices, progress, service
from .models import BoardColumn, Project, ProjectGroup, ProjectMember


def _group_for(user: User, src: Project) -> ProjectGroup | None:
    group = src.group
    return group if group and group.active and group.owner_id in (None, user.id) else None


def _members(user: User, src: Project) -> dict[int, str]:
    rows = ProjectMember.objects.filter(project=src, active=True, user__is_active=True)
    wanted = dict(rows.values_list("user_id", "role"))
    wanted[user.id] = membership.MANAGER
    return wanted


def _copy_columns(src: Project, new: Project) -> dict[int, BoardColumn]:
    mapping = {}
    for column in BoardColumn.objects.filter(project=src, active=True).order_by("rank", "id"):
        mapping[column.id] = BoardColumn.objects.create(project=new, title=column.title, kind=column.kind,
                                                        rank=column.rank)
    return mapping


def _copy_tasks(src: Project, new: Project, user: User, columns: dict[int, BoardColumn]) -> int:
    allowed = membership.member_ids(new.pk)
    fallback = next(iter(columns.values()))
    tasks = Task.objects.filter(project=src, hidden=False).select_related("subject").order_by("rank", "id")
    for task in tasks:
        task_copying.clone_task(task, user, new, columns.get(task.column_id, fallback), task.rank, allowed)
    return tasks.count()


@transaction.atomic
def copy_project(user: User, project_id: UUID, name: str) -> Project:
    service.gate()
    src = service.lock_project(user, project_id, "see")
    if not user.has_grant("project.create"):
        raise HttpError(403, "Permission denied")
    clean = name.strip()
    if not clean:
        raise HttpError(422, "Name is required")
    subject = Subject.objects.create(module=notices.MODULE, kind="project")
    new = Project.objects.create(
        subject=subject, name=clean, description=src.description, group=_group_for(user, src), color=src.color,
        owner=user, start_date=src.start_date, end_date=src.end_date,
        members_can_edit_tasks=src.members_can_edit_tasks, members_can_extend=src.members_can_extend,
        require_removal_approval=src.require_removal_approval)
    wanted = _members(user, src)
    ProjectMember.objects.bulk_create([ProjectMember(project=new, user_id=uid, role=role, added_by=user)
                                       for uid, role in wanted.items()])
    count = _copy_tasks(src, new, user, _copy_columns(src, new))
    progress.recompute(new.pk)
    history.log(subject, user, "status", None, Project.ACTIVE)
    audit(user, "project_copied", str(new.id), source=str(src.id), tasks=count, members=len(wanted))
    mark_seen(user, subject)
    notices.emit_project("project.created", new, user, copied=True)
    notices.notify_added(wanted, new, user)
    return new
