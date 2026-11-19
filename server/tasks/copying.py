"""Copy a task (optionally into another project): new subject, same people/checklist/labels, no comments or history.

File rows of the copy share the encrypted blobs of the original (nothing is duplicated on disk).
"""
from uuid import UUID

from django.db import transaction
from ninja.errors import HttpError

from accounts.models import User, audit
from projects import membership
from workspace.access import visible_labels
from workspace.models import File, Subject, SubjectLabel
from workspace.seen import mark_seen

from . import history, notices, placement, store
from .models import ChecklistItem, Task, TaskPerson


def _people(src: Task, user: User, allowed: set[int] | None) -> list[TaskPerson]:
    """Active people of `src` that may be on the copy; the copier owns it when no owner is left."""
    rows = [p for p in TaskPerson.objects.filter(task=src, active=True).order_by("position", "id")
            if allowed is None or p.user_id in allowed]
    copied = [TaskPerson(role=p.role, user_id=p.user_id, position=p.position) for p in rows]
    if not any(p.role == TaskPerson.OWNER for p in copied):
        copied.append(TaskPerson(role=TaskPerson.OWNER, user_id=user.id))
    return copied


def _copy_children(src: Task, new: Task, user: User, people: list[TaskPerson]) -> None:
    for person in people:
        person.task = new
    TaskPerson.objects.bulk_create(people)
    items = store.active_items(src).order_by("rank", "id")
    ChecklistItem.objects.bulk_create([ChecklistItem(task=new, text=i.text, rank=i.rank) for i in items])
    labels = visible_labels(user).filter(active=True, pk__in=SubjectLabel.objects.filter(
        subject=src.subject, active=True).values("label_id"))
    SubjectLabel.objects.bulk_create([SubjectLabel(subject=new.subject, label=lb, added_by=user) for lb in labels])
    files = File.objects.filter(subject=src.subject, active=True)
    File.objects.bulk_create([
        File(subject=new.subject, uploaded_by_id=f.uploaded_by_id, name=f.name, content_type=f.content_type,
             size=f.size, sha256_plain=f.sha256_plain, blob=f.blob.name, created_at=f.created_at) for f in files])


def clone_task(src: Task, user: User, project, column, rank: int, allowed: set[int] | None) -> tuple[Task, list]:
    """The copy itself (no events, no progress refresh): returns the new task and its people rows."""
    subject = Subject.objects.create(module=notices.MODULE, kind="task")
    new = Task.objects.create(
        subject=subject, title=src.title, description=src.description, creator=user, priority=src.priority,
        start_at=src.start_at, due_at=src.due_at, all_day=src.all_day, progress_mode=src.progress_mode,
        weight=src.weight, project=project, column=column, copied_from=src, rank=rank)
    people = _people(src, user, allowed)
    _copy_children(src, new, user, people)
    history.log(subject, user, "status", None, Task.OPEN)
    return new, people


@transaction.atomic
def copy_task(user: User, task_id: UUID, project_id: UUID | None) -> Task:
    src = store.lock_task(user, task_id)
    if not user.has_grant("task.create"):
        raise HttpError(403, "Permission denied")
    project, column = placement.resolve_target(user, project_id, None)
    allowed = membership.member_ids(project.pk) if project else None
    new, people = clone_task(src, user, project, column, placement.rank_for(column, None, None) if column else 0,
                             allowed)
    subject = new.subject
    audit(user, "task_copied", str(new.id), source=str(src.id))
    store.save(new)
    mark_seen(user, subject)
    notices.emit_task("task.created", new, user, copied=True)
    notices.notify_users({p.user_id for p in people}, "task.assigned", new, user)
    return new
