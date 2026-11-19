"""Attaching tasks to a letter. The caller must be able to see both; the letter detail shows only visible tasks."""
from uuid import UUID

from django.db import transaction
from django.shortcuts import get_object_or_404
from ninja.errors import HttpError

from accounts.models import User, audit
from tasks.models import Task
from tasks.queries import visible_tasks
from tasks.serializers import briefs as task_briefs
from workspace import registry

from . import notices
from .models import Letter, LetterTaskLink
from .schemas import TaskBrief


def tasks_enabled() -> bool:
    return "tasks" in registry.enabled_modules()


def _visible_task(user: User, task_id: UUID) -> Task:
    task = visible_tasks(user).filter(pk=task_id).first()
    if task is None:
        raise HttpError(404, "Task not found")
    return task


def linked(user: User, letter: Letter) -> list[TaskBrief]:
    if not tasks_enabled():
        return []
    ids = letter.task_links.filter(active=True).values("task_id")
    rows = visible_tasks(user).filter(pk__in=ids).order_by("-updated_at", "id")
    return task_briefs(user, list(rows))


@transaction.atomic
def link(user: User, letter: Letter, task_id: UUID) -> TaskBrief:
    registry.require_module("tasks")
    task = _visible_task(user, task_id)
    row, created = LetterTaskLink.objects.get_or_create(letter=letter, task=task, defaults={"added_by": user})
    if created or not row.active:
        if not created:
            LetterTaskLink.objects.filter(pk=row.pk).update(active=True, added_by=user)
        audit(user, "letter_task_linked", str(letter.id), task=str(task.id))
        notices.history(letter.subject, user, "task_link", None, {"task_id": str(task.id)})
        notices.announce(letter, "task_linked", user, task_id=str(task.id))
    return task_briefs(user, [task])[0]


@transaction.atomic
def unlink(user: User, letter: Letter, task_id: UUID) -> None:
    registry.require_module("tasks")
    task = _visible_task(user, task_id)
    row = get_object_or_404(LetterTaskLink, letter=letter, task=task, active=True)
    LetterTaskLink.objects.filter(pk=row.pk).update(active=False)
    audit(user, "letter_task_unlinked", str(letter.id), task=str(task.id))
    notices.history(letter.subject, user, "task_link", {"task_id": str(task.id)}, None)
    notices.announce(letter, "task_unlinked", user, task_id=str(task.id))
