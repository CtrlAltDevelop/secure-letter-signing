"""Removal approval: when a project requires it, creators and owners ask and a project manager decides.

Approval cancels the task and hides it (only the project's managers still see it). Notes are encrypted; audit rows
carry ids only.
"""
from uuid import UUID

from django.db import transaction
from django.utils import timezone
from ninja.errors import HttpError

from accounts.models import User, audit
from accounts.notify import notify
from projects import membership
from workspace.events import emit
from workspace.schemas import user_ref
from workspace.seen import mark_seen
from workspace.textbox import open_text, seal_text

from . import history, notices, store
from .models import RemovalRequest, Task
from .schemas import RemovalOut


def latest_out(task: Task) -> RemovalOut | None:
    row = (RemovalRequest.objects.filter(task=task).select_related("requested_by", "decided_by")
           .order_by("-created_at", "-id").first())
    if row is None:
        return None
    return RemovalOut(
        status=row.status, requested_by=user_ref(row.requested_by), note=open_text(row.note),
        decided_by=user_ref(row.decided_by) if row.decided_by else None, decision_note=open_text(row.decision_note),
        created_at=row.created_at, decided_at=row.decided_at)


def _notify(kind: str, ids: set[int], task: Task, actor: User) -> None:
    users = list(User.objects.filter(pk__in=ids - {actor.id}, is_active=True))
    if users:
        notify(users, kind, task.title, module=notices.MODULE, subject_id=str(task.subject_id),
               object_id=str(task.id))


def _pending(task: Task) -> RemovalRequest | None:
    return RemovalRequest.objects.select_for_update().filter(task=task, status=RemovalRequest.PENDING).first()


@transaction.atomic
def request_removal(user: User, task_id: UUID, note: str) -> Task:
    task = store.lock_task(user, task_id)
    store.require(user, task, "request_removal")
    if _pending(task):
        raise HttpError(409, "A removal request is already pending")
    RemovalRequest.objects.create(task=task, requested_by=user, note=seal_text(note.strip()))
    managers = membership.manager_ids(task.project_id)
    history.log(task.subject, user, "removal", None, "requested")
    audit(user, "task_removal_requested", str(task.id))
    emit(notices.MODULE, "task.removal_requested", task.subject, task.title, user, managers - {user.id},
         object_id=str(task.id))
    _notify("task.removal_requested", managers, task, user)
    mark_seen(user, task.subject)
    return task


@transaction.atomic
def decide_removal(user: User, task_id: UUID, decision: str, note: str) -> Task:
    task = store.lock_task(user, task_id)
    store.require(user, task, "decide_removal")
    row = _pending(task)
    if row is None:
        raise HttpError(409, "There is no pending removal request")
    if decision == "reject" and not note.strip():
        raise HttpError(422, "A rejection needs a note")
    approved = decision == "approve"
    row.status = RemovalRequest.APPROVED if approved else RemovalRequest.REJECTED
    row.decided_by, row.decided_at, row.decision_note = user, timezone.now(), seal_text(note.strip())
    row.save()
    if approved:
        if task.status != Task.CANCELLED:
            history.log(task.subject, user, "status", task.status, Task.CANCELLED)
            task.status, task.completed_at = Task.CANCELLED, None
        history.log(task.subject, user, "hidden", False, True)
        task.hidden = True
        task.version += 1
        store.save(task)
    history.log(task.subject, user, "removal", "requested", row.status)
    audit(user, "task_removal_decided", str(task.id), decision=row.status)
    recipients = {row.requested_by_id} | (membership.manager_ids(task.project_id) if approved else set())
    emit(notices.MODULE, "task.removal_decided", task.subject, task.title, user, recipients - {user.id},
         object_id=str(task.id), decision=row.status)
    _notify(f"task.removal_{row.status}", {row.requested_by_id}, task, user)
    mark_seen(user, task.subject)
    return task
