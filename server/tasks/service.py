"""Create tasks, edit their fields, replace their people."""
from uuid import UUID

from django.db import transaction
from ninja.errors import HttpError

from accounts import guests
from accounts.models import User, audit
from crm import service as crm_service
from crm import timeline as crm_timeline
from projects import progress
from workspace.access import visible_labels
from workspace.models import Subject, SubjectLabel
from workspace.seen import mark_seen
from workspace.textbox import open_text, seal_text

from . import history, notices, placement, rules, store, workflow
from .models import ChecklistItem, Task, TaskPerson
from .schemas import MoveIn, PeopleIn, TaskIn, TaskPatch

OWNER, APPROVER, FOLLOWER = TaskPerson.OWNER, TaskPerson.APPROVER, TaskPerson.FOLLOWER


def unique(ids: list[int]) -> list[int]:
    return list(dict.fromkeys(ids))


def check_users(ids: list[int], actor: User) -> None:
    if User.objects.filter(pk__in=ids, is_active=True).count() != len(set(ids)) or guests.referable_ids(actor, ids) != set(ids):
        raise HttpError(422, "Unknown or inactive user")


def check_dates(start_at, due_at) -> None:
    if start_at and due_at and due_at < start_at:
        raise HttpError(422, "The due date is before the start date")


def linked_customer(user: User, customer_id: UUID | None):
    """The customer file to link (manager/member of the file and `task.create` needed), or None."""
    if customer_id is None:
        return None
    if not user.has_grant("task.create"):
        raise HttpError(403, "Permission denied")
    return crm_service.linkable(user, customer_id)


def _add_people(task: Task, owners: list[int], approvers: list[int], followers: list[int]) -> None:
    rows = [TaskPerson(task=task, user_id=u, role=OWNER) for u in owners]
    rows += [TaskPerson(task=task, user_id=u, role=APPROVER, position=i) for i, u in enumerate(approvers)]
    rows += [TaskPerson(task=task, user_id=u, role=FOLLOWER) for u in followers]
    TaskPerson.objects.bulk_create(rows)


def _checked_labels(user: User, label_ids: list[int]) -> list[int]:
    wanted = set(label_ids)
    found = set(visible_labels(user).filter(pk__in=wanted, active=True).values_list("pk", flat=True))
    if found != wanted:
        raise HttpError(422, "Unknown or inactive label")
    return sorted(wanted)


@transaction.atomic
def create_task(user: User, data: TaskIn) -> Task:
    owners = unique(data.owner_ids) or [user.id]
    approvers, followers = unique(data.approver_ids), unique(data.follower_ids)
    check_users(unique(owners + approvers + followers), user)
    check_dates(data.start_at, data.due_at)
    texts = [t.strip() for t in data.checklist]
    if not all(texts):
        raise HttpError(422, "Checklist items cannot be empty")
    labels = _checked_labels(user, data.label_ids)
    project, column = placement.resolve_target(user, data.project_id, data.column_id)
    customer = linked_customer(user, data.customer_id)
    if project:
        placement.check_people_in_project(project, owners + approvers + followers)
    subject = Subject.objects.create(module=notices.MODULE, kind="task")
    description = seal_text(data.description.text if data.description else "")
    task = Task.objects.create(
        subject=subject, title=data.title.strip(), description=description, creator=user, priority=data.priority,
        start_at=data.start_at, due_at=data.due_at, all_day=data.all_day, project=project, column=column,
        customer=customer, weight=data.weight,
        rank=placement.rank_for(column, None, None) if column else 0)
    progress.recompute(task.project_id)
    _add_people(task, owners, approvers, followers)
    ChecklistItem.objects.bulk_create(
        [ChecklistItem(task=task, text=t, rank=(i + 1) * store.RANK_GAP) for i, t in enumerate(texts)])
    SubjectLabel.objects.bulk_create([SubjectLabel(subject=subject, label_id=i, added_by=user) for i in labels])
    history.log(subject, user, "status", None, Task.OPEN)
    if customer:
        crm_timeline.record(customer, "task", f"Task linked: {task.title}", user, subject)
    audit(user, "task_created", str(task.id))
    mark_seen(user, subject)
    notices.emit_task("task.created", task, user)
    notices.notify_users(owners + approvers + followers, "task.assigned", task, user)
    return task


def _description_change(task: Task, data: TaskPatch) -> dict:
    new_text = data.description.text if data.description else ""
    if new_text == open_text(task.description):
        return {}
    task.description = seal_text(new_text)
    return {"description": (None, None)}


def _extension_allowed(user: User, task: Task, new_due) -> bool:
    """A due date moves later when it is cleared or set after the current one (a first deadline is never later)."""
    old = task.due_at
    later = old is not None and (new_due is None or new_due > old)
    return not later or rules.may_extend(user, task)


def _scalar_changes(user: User, task: Task, data: TaskPatch, fields: set[str]) -> dict:
    changes = {}
    for name in ("title", "priority", "start_at", "due_at", "all_day", "progress_mode", "weight"):
        if name not in fields:
            continue
        value = getattr(data, name)
        if name == "title" and value is not None:
            value = value.strip()
        if name == "due_at" and not _extension_allowed(user, task, value):
            raise HttpError(403, "Members of this project may not move a due date later")
        if value in (None, "") and name not in ("start_at", "due_at"):
            raise HttpError(422, f"{name} cannot be empty")
        if getattr(task, name) != value:
            changes[name] = (getattr(task, name), value)
            setattr(task, name, value)
    return changes


def _customer_change(user: User, task: Task, data: TaskPatch, fields: set[str]) -> dict:
    if "customer_id" not in fields or data.customer_id == task.customer_id:
        return {}
    old_id, new = task.customer_id, linked_customer(user, data.customer_id)
    task.customer = new
    if new:
        crm_timeline.record(new, "task", f"Task linked: {task.title}", user, task.subject)
    return {"customer": (str(old_id) if old_id else None, str(new.id) if new else None)}


def _progress_change(task: Task, data: TaskPatch, fields: set[str], mode_changed: bool) -> dict:
    if "progress" in fields and task.progress_mode == Task.CHECKLIST:
        raise HttpError(422, "Progress is computed from the checklist")
    if mode_changed and task.progress_mode == Task.CHECKLIST:
        new = store.checklist_progress(task)
    else:
        new = data.progress if "progress" in fields else task.progress
    if new is None:
        raise HttpError(422, "progress cannot be empty")
    if new == task.progress:
        return {}
    old, task.progress = task.progress, new
    return {"progress": (old, new)}


def _required_actions(fields: set[str]) -> set[str]:
    actions = set()
    if "progress" in fields:
        actions.add("progress")
    if fields - {"progress"}:
        actions.add("edit")
    return actions


@transaction.atomic
def update_task(user: User, task_id: UUID, data: TaskPatch) -> Task:
    task = store.lock_task(user, task_id)
    fields = data.model_fields_set - {"version"}
    moving = "project_id" in fields and data.project_id != task.project_id
    fields.discard("project_id")
    if moving:
        store.require(user, task, "move")
    for action in sorted(_required_actions(fields)):
        store.require(user, task, action)
    if data.version != task.version:
        raise HttpError(409, "The task was changed by someone else; reload it")
    changes = _scalar_changes(user, task, data, fields)
    changes.update(_customer_change(user, task, data, fields))
    check_dates(task.start_at, task.due_at)
    changes.update(_progress_change(task, data, fields, "progress_mode" in changes))
    if "description" in fields:
        changes.update(_description_change(task, data))
    if changes:
        task.version += 1
        store.save(task)
        history.log_all(task.subject, user, changes)
        notices.emit_task("task.updated", task, user, fields=sorted(changes))
    if moving:
        task = placement.move_locked(user, task, MoveIn(project_id=data.project_id))
    mark_seen(user, task.subject)
    return task


def set_progress(task: Task, user: User, value: int) -> int:
    """Registry callback for `report` comments: owners set manual progress."""
    with transaction.atomic():
        locked = store.lock_task(user, task.pk)
        if locked.progress_mode == Task.CHECKLIST:
            raise HttpError(422, "Progress is computed from the checklist")
        if locked.progress != value:
            old, locked.progress = locked.progress, value
            store.save(locked)
            history.log(locked.subject, user, "progress", old, value)
            notices.emit_task("task.updated", locked, user, fields=["progress"])
    return value


def _role_ids(task: Task, role: str) -> list[int]:
    return list(store.active_people(task, role).order_by("position", "id").values_list("user_id", flat=True))


def _sync_role(task: Task, role: str, ids: list[int]) -> None:
    """Make exactly `ids` (in order) the active people with `role`; others are deactivated, never deleted."""
    existing = {p.user_id: p for p in TaskPerson.objects.filter(task=task, role=role)}
    for position, uid in enumerate(ids):
        row = existing.get(uid)
        if row is None:
            TaskPerson.objects.create(task=task, user_id=uid, role=role, position=position)
        elif not row.active or row.position != position:
            row.active, row.position = True, position
            row.save(update_fields=["active", "position"])
    for uid, row in existing.items():
        if uid not in ids and row.active:
            row.active = False
            row.save(update_fields=["active"])


@transaction.atomic
def set_people(user: User, task_id: UUID, data: PeopleIn) -> Task:
    task = store.lock_task(user, task_id)
    store.require(user, task, "edit")
    wanted = {OWNER: unique(data.owner_ids), APPROVER: unique(data.approver_ids), FOLLOWER: unique(data.follower_ids)}
    everyone = unique([u for ids in wanted.values() for u in ids])
    check_users(everyone, user)
    if task.project_id:
        placement.check_people_in_project(task.project, everyone)
    before = {role: _role_ids(task, role) for role in wanted}
    involved_before = rules.audience(task)
    waiting_before = rules.current_approver_id(task)
    changes = {}
    for role, ids in wanted.items():
        if before[role] != ids:
            _sync_role(task, role, ids)
            changes[f"{role}s"] = (before[role], ids)
    if changes:
        history.log_all(task.subject, user, changes)
        workflow.settle_after_people_change(task, user, waiting_before)
        notices.emit_task("task.updated", task, user, fields=sorted(changes))
        added = {u for ids in wanted.values() for u in ids} - involved_before
        notices.notify_users(added, "task.assigned", task, user)
    mark_seen(user, task.subject)
    return task
