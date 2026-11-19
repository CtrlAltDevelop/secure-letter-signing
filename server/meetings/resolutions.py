"""Resolutions and their follow-up tasks.

A resolution with owners is backed by a normal task (made through the tasks service, in the meeting's project when it
has one). The resolution's status mirrors the task through a `post_save` hook, so completion shows in the meeting.
"""
from uuid import UUID

from django.db import transaction
from django.db.models.signals import post_save
from ninja.errors import HttpError

from accounts.models import User
from tasks import service as task_service
from tasks import workflow
from tasks.models import Task, TaskPerson
from tasks.schemas import DescriptionIn, PeopleIn, TaskIn, TaskPatch
from workspace.seen import mark_seen
from workspace.textbox import open_text, seal_text

from . import content, history, notices, store
from .models import Meeting, Resolution, ResolutionOwner
from .schemas import ResolutionIn, ResolutionPatch

TITLE_CHARS = 200
TASK_STATUS_TO_RESOLUTION = {Task.DONE: Resolution.DONE, Task.CANCELLED: Resolution.CANCELLED,
                             Task.OPEN: Resolution.OPEN, Task.AWAITING: Resolution.OPEN}


def task_title(text: str) -> str:
    return " ".join(text.split())[:TITLE_CHARS] or "Resolution"


def owner_ids(resolution: Resolution) -> list[int]:
    return sorted(ResolutionOwner.objects.filter(resolution=resolution, active=True).values_list("user_id", flat=True))


def _check_owners(ids: list[int]) -> list[int]:
    ids = list(dict.fromkeys(ids))
    if User.objects.filter(pk__in=ids, is_active=True).count() != len(ids):
        raise HttpError(422, "Unknown or inactive user")
    return ids


def _sync_owners(resolution: Resolution, ids: list[int]) -> None:
    rows = {o.user_id: o for o in ResolutionOwner.objects.filter(resolution=resolution)}
    for uid in ids:
        row = rows.get(uid)
        if row is None:
            ResolutionOwner.objects.create(resolution=resolution, user_id=uid)
        elif not row.active:
            row.active = True
            row.save(update_fields=["active"])
    for uid, row in rows.items():
        if uid not in ids and row.active:
            row.active = False
            row.save(update_fields=["active"])


def _create_task(user: User, meeting: Meeting, resolution: Resolution, text: str, ids: list[int]) -> Task:
    if not user.has_grant("task.create"):
        raise HttpError(403, "Creating a follow-up task needs the task.create permission")
    link = f"Follow-up of a resolution of the meeting '{meeting.title}' (meeting:{meeting.id}, resolution:{resolution.id})"
    body = TaskIn(title=task_title(text), description=DescriptionIn(text=f"{link}\n\n{text}"[:50_000]),
                  due_at=resolution.due_at, owner_ids=ids, project_id=meeting.project_id)
    return task_service.create_task(user, body)


def _sync_task(resolution: Resolution, patch_fields: dict, owners: list[int] | None) -> None:
    """Push edits to the linked task, acting as the task's creator (the recorder who may not be it)."""
    task = Task.objects.get(pk=resolution.task_id)
    if task.status not in (Task.OPEN, Task.AWAITING):
        return
    if patch_fields:
        task_service.update_task(task.creator, task.id, TaskPatch(version=task.version, **patch_fields))
    if owners is not None:
        people = task.people.filter(active=True)
        keep = lambda role: [p.user_id for p in people.filter(role=role).order_by("position", "id")]  # noqa: E731
        task_service.set_people(task.creator, task.id, PeopleIn(
            owner_ids=owners, approver_ids=keep(TaskPerson.APPROVER), follower_ids=keep(TaskPerson.FOLLOWER)))


def _locked_for_minutes(user: User, meeting_id: UUID) -> Meeting:
    meeting = store.lock_meeting(user, meeting_id)
    store.require(user, meeting, "record")
    content.require_minutes_editable(meeting)
    return meeting


@transaction.atomic
def add(user: User, meeting_id: UUID, data: ResolutionIn) -> Resolution:
    meeting = _locked_for_minutes(user, meeting_id)
    ids = _check_owners(data.owner_ids)
    text = data.text.strip()
    if not text:
        raise HttpError(422, "text cannot be empty")
    resolution = Resolution.objects.create(meeting=meeting, text=seal_text(text), due_at=data.due_at, created_by=user)
    _sync_owners(resolution, ids)
    if ids:
        resolution.task = _create_task(user, meeting, resolution, text, ids)
        resolution.save(update_fields=["task"])
    history.log(meeting.subject, user, f"resolution:{resolution.id}:created", None, {"owners": ids})
    store.save(meeting)
    notices.emit_meeting("meeting.resolution", meeting, user, resolution_id=resolution.id)
    mark_seen(user, meeting.subject)
    return resolution


def _changes(user: User, meeting: Meeting, resolution: Resolution, data: ResolutionPatch) -> dict:
    fields, changes, task_fields = data.model_fields_set, {}, {}
    if "text" in fields and data.text is not None:
        text = data.text.strip()
        if not text:
            raise HttpError(422, "text cannot be empty")
        if text != open_text(resolution.text):
            resolution.text = seal_text(text)
            changes["text"] = (None, None)
            task_fields["title"] = task_title(text)
    if "due_at" in fields and data.due_at != resolution.due_at:
        changes["due_at"] = (resolution.due_at, data.due_at)
        resolution.due_at = task_fields["due_at"] = data.due_at
    if "status" in fields and data.status and data.status != resolution.status:
        if resolution.task_id:
            raise HttpError(409, "The status follows the follow-up task")
        changes["status"] = (resolution.status, data.status)
        resolution.status = data.status
    return {"fields": changes, "task": task_fields}


@transaction.atomic
def edit(user: User, meeting_id: UUID, resolution_id: int, data: ResolutionPatch) -> Resolution:
    meeting = _locked_for_minutes(user, meeting_id)
    resolution = Resolution.objects.select_for_update().filter(pk=resolution_id, meeting=meeting, active=True).first()
    if resolution is None:
        raise HttpError(404, "Not found")
    parts = _changes(user, meeting, resolution, data)
    changes, new_owners = parts["fields"], None
    if data.owner_ids is not None:
        new_owners = _check_owners(data.owner_ids)
        old = owner_ids(resolution)
        if sorted(new_owners) != old:
            changes["owners"] = (old, sorted(new_owners))
    if data.active is False:
        _deactivate(user, resolution, changes)
    else:
        _apply_owners_and_task(user, meeting, resolution, parts["task"], new_owners, changes)
    resolution.save()
    history.log_all(meeting.subject, user, {f"resolution:{resolution.id}:{k}": v for k, v in changes.items()})
    store.save(meeting)
    notices.emit_meeting("meeting.resolution", meeting, user, resolution_id=resolution.id)
    mark_seen(user, meeting.subject)
    return resolution


def _apply_owners_and_task(user, meeting, resolution, task_fields, new_owners, changes) -> None:
    if new_owners is not None and "owners" in changes:
        if resolution.task_id and not new_owners:
            raise HttpError(422, "A resolution with a follow-up task needs an owner; deactivate it instead")
        _sync_owners(resolution, new_owners)
    if resolution.task_id:
        _sync_task(resolution, task_fields, new_owners if "owners" in changes else None)
    elif new_owners:
        resolution.task = _create_task(user, meeting, resolution, open_text(resolution.text), new_owners)


def _deactivate(user: User, resolution: Resolution, changes: dict) -> None:
    resolution.active = False
    changes["active"] = (True, False)
    resolution.save()  # before cancelling: the task hook only mirrors into active resolutions
    if resolution.task_id:
        task = Task.objects.get(pk=resolution.task_id)
        if task.status in (Task.OPEN, Task.AWAITING):
            workflow.cancel(task.creator, task.id)


def mirror_task(sender, instance: Task, **kwargs) -> None:
    """post_save on Task: the resolutions that follow it take its status (done/cancelled/open)."""
    status = TASK_STATUS_TO_RESOLUTION.get(instance.status, Resolution.OPEN)
    for resolution in Resolution.objects.filter(task=instance, active=True).exclude(status=status):
        history.log(resolution.meeting.subject, None, f"resolution:{resolution.id}:status", resolution.status, status)
        Resolution.objects.filter(pk=resolution.pk).update(status=status)


def connect_task_mirror() -> None:
    post_save.connect(mirror_task, sender=Task, dispatch_uid="meetings.mirror_task")
