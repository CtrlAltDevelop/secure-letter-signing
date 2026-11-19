"""Checklist items: add, change, reorder. Owners tick items; owners and the creator edit them."""
from uuid import UUID

from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja.errors import HttpError

from accounts.models import User
from workspace.seen import mark_seen

from . import history, notices, rules, store
from .models import ChecklistItem, Task
from .schemas import MAX_CHECKLIST, ChecklistAdd, ChecklistOrder, ChecklistPatch


def _require_edit_or_progress(user: User, task: Task) -> None:
    if rules.can(user, task, "edit") or rules.can(user, task, "progress"):
        return
    owner_like = rules.roles_of(user, task) - {rules.CREATOR}
    store.require(user, task, "progress" if "owner" in owner_like else "edit")


def _after_change(task: Task, user: User, detail: dict) -> None:
    changes = {"checklist": (None, detail)}
    if task.progress_mode == Task.CHECKLIST:
        new = store.checklist_progress(task)
        if new != task.progress:
            changes["progress"] = (task.progress, new)
            task.progress = new
    store.save(task)
    history.log_all(task.subject, user, changes)
    notices.emit_task("task.updated", task, user, fields=sorted(changes))
    mark_seen(user, task.subject)


@transaction.atomic
def add_item(user: User, task_id: UUID, data: ChecklistAdd) -> Task:
    task = store.lock_task(user, task_id)
    _require_edit_or_progress(user, task)
    text = data.text.strip()
    if not text:
        raise HttpError(422, "Text is required")
    if store.active_items(task).count() >= MAX_CHECKLIST:
        raise HttpError(422, "Too many checklist items")
    item = ChecklistItem.objects.create(task=task, text=text, rank=store.next_rank(task))
    _after_change(task, user, {"added": item.id, "text": text})
    return task


@transaction.atomic
def patch_item(user: User, task_id: UUID, item_id: int, data: ChecklistPatch) -> Task:
    task = store.lock_task(user, task_id)
    item = get_object_or_404(ChecklistItem, pk=item_id, task=task, active=True)
    fields = data.model_fields_set
    if "done" in fields:
        store.require(user, task, "progress")
    if fields - {"done"}:
        _require_edit_or_progress(user, task)
    detail: dict = {"item": item.id}
    if data.text is not None and data.text.strip() != item.text:
        item.text = data.text.strip()
        detail["text"] = item.text
    if data.done is not None and data.done != item.done:
        item.done = data.done
        item.done_by = user if data.done else None
        item.done_at = timezone.now() if data.done else None
        detail["done"] = data.done
    if data.active is False:
        item.active = False
        detail["removed"] = True
    if len(detail) > 1:
        item.save()
        _after_change(task, user, detail)
    return task


@transaction.atomic
def reorder(user: User, task_id: UUID, data: ChecklistOrder) -> Task:
    task = store.lock_task(user, task_id)
    _require_edit_or_progress(user, task)
    items = {i.id: i for i in store.active_items(task)}
    if sorted(data.item_ids) != sorted(items):
        raise HttpError(422, "item_ids must list every active checklist item exactly once")
    for position, item_id in enumerate(data.item_ids, start=1):
        if items[item_id].rank != position * store.RANK_GAP:
            ChecklistItem.objects.filter(pk=item_id).update(rank=position * store.RANK_GAP)
    _after_change(task, user, {"order": data.item_ids})
    return task
