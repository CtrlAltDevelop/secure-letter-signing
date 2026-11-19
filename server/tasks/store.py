"""Row access shared by the task services: locking, people, checklist counts, progress, timestamps."""
from uuid import UUID

from django.db.models import QuerySet
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja.errors import HttpError

from accounts.models import User
from projects import progress as project_progress

from . import rules
from .models import ChecklistItem, Task, TaskPerson

RANK_GAP = 65_536


def lock_task(user: User, task_id: UUID) -> Task:
    """The task row locked for update. 404 unless the user can see it. Call inside `transaction.atomic`."""
    task = get_object_or_404(Task.objects.select_for_update().select_related("subject"), pk=task_id)
    if not rules.can(user, task, "see"):
        raise HttpError(404, "Not found")
    return task


def require(user: User, task: Task, action: str) -> None:
    code = rules.denial(user, task, action)
    if code == 409:
        raise HttpError(409, "The task is not in a state that allows this")
    if code:
        raise HttpError(code, "Permission denied")


def save(task: Task) -> None:
    task.updated_at = timezone.now()
    task.save()
    project_progress.recompute(task.project_id)


def active_people(task: Task, role: str | None = None) -> QuerySet[TaskPerson]:
    rows = TaskPerson.objects.filter(task=task, active=True)
    return rows.filter(role=role) if role else rows


def active_items(task: Task) -> QuerySet[ChecklistItem]:
    return ChecklistItem.objects.filter(task=task, active=True)


def checklist_progress(task: Task) -> int:
    items = active_items(task)
    total = items.count()
    return round(100 * items.filter(done=True).count() / total) if total else 0


def next_rank(task: Task) -> int:
    last = active_items(task).order_by("-rank").first()
    return (last.rank if last else 0) + RANK_GAP
