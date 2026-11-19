"""When every prerequisite of a task is done, tell the task's owners (once). Hooked on Task post_save like
meetings' resolution mirror, so it works whichever path finished the task."""
from django.db.models.signals import post_save
from django.utils import timezone

from accounts.models import User
from accounts.notify import notify
from tasks.models import Task, TaskPerson
from workspace.events import emit

from .models import GanttItem, GanttLink

MODULE = "gantt"


def check(successor: Task) -> None:
    """Notify the owners of `successor` if it is planned, open, has prerequisites and all of them are done."""
    item = GanttItem.objects.filter(task=successor, active=True, ready_notified_at__isnull=True).first()
    if item is None or successor.status in (Task.DONE, Task.CANCELLED):
        return
    states = list(Task.objects.filter(
        pk__in=GanttLink.objects.filter(successor=successor, active=True).values("predecessor")
    ).values_list("status", flat=True))
    if not states or any(s != Task.DONE for s in states):
        return
    claimed = GanttItem.objects.filter(pk=item.pk, ready_notified_at__isnull=True).update(ready_notified_at=timezone.now())
    if not claimed:  # a concurrent save got there first
        return
    owner_ids = set(TaskPerson.objects.filter(task=successor, role=TaskPerson.OWNER, active=True)
                    .values_list("user_id", flat=True))
    project = item.project
    emit(MODULE, "gantt.task_ready", project.subject, successor.title, None, owner_ids,
         object_id=str(project.id), task_id=str(successor.id))
    notify(list(User.objects.filter(pk__in=owner_ids, is_active=True)), "gantt.task_ready", successor.title,
           module=MODULE, subject_id=str(project.subject_id), object_id=str(project.id), task_id=str(successor.id))


def on_task_saved(sender, instance: Task, **kwargs) -> None:
    links = GanttLink.objects.filter(predecessor=instance, active=True)
    if instance.status == Task.DONE:
        for link in links.select_related("successor"):
            check(link.successor)
    elif links.exists():  # a reopened prerequisite re-arms the notice
        GanttItem.objects.filter(task__in=links.values("successor"), ready_notified_at__isnull=False).update(
            ready_notified_at=None)


def connect() -> None:
    post_save.connect(on_task_saved, sender=Task, dispatch_uid="gantt.task_ready")
