"""Work transfer for tasks: open tasks owned or created by the source, and the source's personal templates."""
from django.db.models import Exists, OuterRef, Q

from accounts.models import User
from projects import membership

from . import history, notices, rules, store
from .models import Task, TaskPerson, TaskTemplate

OPEN_STATES = (Task.OPEN, Task.AWAITING)


def _open_tasks(user: User):
    involved = Exists(TaskPerson.objects.filter(task=OuterRef("pk"), user=user, active=True))
    return Task.objects.select_for_update().filter(status__in=OPEN_STATES, hidden=False).filter(
        Q(creator=user) | involved)


def _move_people(task: Task, from_user: User, to_user: User) -> None:
    """The source's active roles go to the target (a decision already taken travels along); source rows end."""
    for row in TaskPerson.objects.filter(task=task, user=from_user, active=True):
        target = TaskPerson.objects.filter(task=task, user=to_user, role=row.role).first()
        if target is None:
            TaskPerson.objects.create(task=task, user=to_user, role=row.role, position=row.position,
                                      decision=row.decision, decided_at=row.decided_at)
        elif not target.active:
            target.active, target.position = True, row.position
            target.decision, target.decided_at = row.decision, row.decided_at
            target.save()
        row.active = False
        row.save(update_fields=["active"])


def _move_task(task: Task, from_user: User, to_user: User, actor: User) -> None:
    waiting_before = rules.current_approver_id(task)
    _move_people(task, from_user, to_user)
    if task.creator_id == from_user.id:
        task.creator = to_user
    task.version += 1
    store.save(task)
    history.log(task.subject, actor, "transfer", {"from": from_user.id}, {"to": to_user.id})
    notices.emit_task("task.updated", task, actor, fields=["people"], transferred=True)
    waiting_now = rules.current_approver_id(task)
    if task.status == Task.AWAITING and waiting_now == to_user.id and waiting_now != waiting_before:
        notices.notify_users([to_user.id], "task.approval_needed", task, actor)


def transfer(from_user: User, to_user: User, actor: User) -> dict[str, int]:
    """Moves open tasks (skipping project tasks the target cannot see) and personal templates."""
    moved = 0
    for task in _open_tasks(from_user):
        if task.project_id and to_user.id not in membership.member_ids(task.project_id):
            continue
        _move_task(task, from_user, to_user, actor)
        moved += 1
    templates = TaskTemplate.objects.filter(owner=from_user).update(owner=to_user)
    return {"tasks": moved, "task_templates": templates}
