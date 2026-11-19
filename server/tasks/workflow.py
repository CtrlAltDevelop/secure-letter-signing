"""The task state machine: complete -> (awaiting_approval ->) done, rejection -> open, reopen, cancel.

Approvers decide serially by `position`. Audit rows carry ids only, never titles.
"""
from uuid import UUID

from django.db import transaction
from django.utils import timezone
from ninja.errors import HttpError

from accounts.models import User, audit
from projects import membership
from workspace import comments
from workspace.seen import mark_seen

from . import history, notices, rules, store
from .models import Task, TaskPerson


def _set_status(task: Task, user: User, status: str) -> None:
    history.log(task.subject, user, "status", task.status, status)
    task.status = status
    task.completed_at = timezone.now() if status == Task.DONE else None


def _reset_decisions(task: Task) -> None:
    store.active_people(task, TaskPerson.APPROVER).update(decision="", decided_at=None)


def _ask_next_approver(task: Task, user: User) -> None:
    if task.status != Task.AWAITING:
        return
    next_id = rules.current_approver_id(task)
    if next_id:
        notices.notify_users([next_id], "task.approval_needed", task, user)


def _note(task: Task, user: User, text: str) -> None:
    if text.strip():
        comments.add_note(task.subject, user, text.strip(), task.progress)


@transaction.atomic
def complete(user: User, task_id: UUID, note: str) -> Task:
    task = store.lock_task(user, task_id)
    store.require(user, task, "complete")
    _note(task, user, note)
    if task.progress != 100:
        history.log(task.subject, user, "progress", task.progress, 100)
        task.progress = 100
    awaiting = store.active_people(task, TaskPerson.APPROVER).exists()
    if awaiting:
        _reset_decisions(task)
    _set_status(task, user, Task.AWAITING if awaiting else Task.DONE)
    store.save(task)
    audit(user, "task_completed", str(task.id), status=task.status)
    notices.emit_task("task.completed", task, user, status=task.status)
    _ask_next_approver(task, user)
    mark_seen(user, task.subject)
    return task


def _finish_approved(task: Task, user: User) -> None:
    _set_status(task, user, Task.DONE)


@transaction.atomic
def decide(user: User, task_id: UUID, decision: str, note: str) -> Task:
    task = store.lock_task(user, task_id)
    store.require(user, task, "approve")
    if decision == "reject" and not note.strip():
        raise HttpError(422, "A rejection needs a note")
    row = store.active_people(task, TaskPerson.APPROVER).get(user=user)
    row.decision = TaskPerson.APPROVED if decision == "approve" else TaskPerson.REJECTED
    row.decided_at = timezone.now()
    row.save(update_fields=["decision", "decided_at"])
    history.log(task.subject, user, "decision", None, {"user_id": user.id, "decision": row.decision})
    if decision == "reject":
        _note(task, user, note)
        _set_status(task, user, Task.OPEN)
        kind, extra = "task.rejected", {}
    else:
        final = rules.current_approver_id(task) is None
        if final:
            _finish_approved(task, user)
        kind, extra = "task.approved", {"final": final}
    store.save(task)
    audit(user, "task_decision", str(task.id), decision=row.decision)
    notices.emit_task(kind, task, user, status=task.status, **extra)
    _ask_next_approver(task, user)
    mark_seen(user, task.subject)
    return task


def settle_after_people_change(task: Task, user: User, waiting_before: int | None) -> None:
    """People changed while awaiting approval: finish if nobody is left to approve, else ask the new current one."""
    if task.status != Task.AWAITING:
        return
    waiting_now = rules.current_approver_id(task)
    if waiting_now is None:
        _finish_approved(task, user)
        store.save(task)
    elif waiting_now != waiting_before:
        notices.notify_users([waiting_now], "task.approval_needed", task, user)


def _is_project_manager(user: User, task: Task) -> bool:
    return membership.role_in(user, task.project_id) == membership.MANAGER


@transaction.atomic
def cancel(user: User, task_id: UUID) -> Task:
    task = store.lock_task(user, task_id)
    store.require(user, task, "edit")
    if task.project_id and task.project.require_removal_approval and not _is_project_manager(user, task):
        raise HttpError(403, "This project requires a removal request")
    _set_status(task, user, Task.CANCELLED)
    store.save(task)
    audit(user, "task_cancelled", str(task.id))
    notices.emit_task("task.cancelled", task, user)
    mark_seen(user, task.subject)
    return task


@transaction.atomic
def reopen(user: User, task_id: UUID) -> Task:
    task = store.lock_task(user, task_id)
    store.require(user, task, "reopen")
    _reset_decisions(task)
    _set_status(task, user, Task.OPEN)
    if task.hidden:
        history.log(task.subject, user, "hidden", True, False)
        task.hidden = False
    if task.progress_mode == Task.CHECKLIST:
        task.progress = store.checklist_progress(task)
    store.save(task)
    audit(user, "task_reopened", str(task.id))
    notices.emit_task("task.updated", task, user, fields=["status"], reopened=True)
    mark_seen(user, task.subject)
    return task
