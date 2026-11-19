"""Gantt plan of a project: phases, one plan row per task, and finish-to-start links. Nothing is deleted."""
from django.db import models
from django.utils import timezone

from accounts.models import User


class GanttPhase(models.Model):
    """A group of tasks. `start_at`/`end_at` are optional overrides; otherwise they derive from the tasks inside."""

    project = models.ForeignKey("projects.Project", on_delete=models.PROTECT, related_name="gantt_phases")
    title = models.CharField(max_length=200)  # plaintext, like task titles
    position = models.PositiveIntegerField(default=0)
    start_at = models.DateField(null=True, blank=True)
    end_at = models.DateField(null=True, blank=True)
    active = models.BooleanField(default=True)
    created_at = models.DateTimeField(default=timezone.now)


class GanttItem(models.Model):
    """The plan row of one task. Only root items carry a phase; children (WBS levels below) follow their parent."""

    task = models.OneToOneField("tasks.Task", on_delete=models.PROTECT, related_name="gantt_item")
    project = models.ForeignKey("projects.Project", on_delete=models.PROTECT, related_name="gantt_items")
    phase = models.ForeignKey(GanttPhase, null=True, blank=True, on_delete=models.PROTECT, related_name="items")
    parent = models.ForeignKey("self", null=True, blank=True, on_delete=models.PROTECT, related_name="children")
    position = models.PositiveIntegerField(default=0)
    start_at = models.DateField(null=True, blank=True)  # empty: the task's own start date
    end_at = models.DateField(null=True, blank=True)  # empty: the task's due date
    active = models.BooleanField(default=True)
    ready_notified_at = models.DateTimeField(null=True, blank=True)  # all prerequisites done and owners told


class GanttLink(models.Model):
    """`successor` may start when `predecessor` is finished (finish-to-start, the only kind)."""

    FINISH_TO_START = "fs"

    project = models.ForeignKey("projects.Project", on_delete=models.PROTECT, related_name="gantt_links")
    predecessor = models.ForeignKey("tasks.Task", on_delete=models.PROTECT, related_name="+")
    successor = models.ForeignKey("tasks.Task", on_delete=models.PROTECT, related_name="+")
    kind = models.CharField(max_length=2, default=FINISH_TO_START)
    active = models.BooleanField(default=True)
    created_by = models.ForeignKey(User, null=True, on_delete=models.PROTECT, related_name="+")
    at = models.DateTimeField(default=timezone.now)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["predecessor", "successor"], name="one_gantt_link_per_pair")]
