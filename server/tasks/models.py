"""Tasks. Titles are plaintext; the description is encrypted at rest ({"v":3,"ct":..}). Nothing is deleted.

A task is personal (project null) or lives in a project board column; `rank` orders it inside its column.
"""
import uuid

from django.conf import settings
from django.db import models
from django.utils import timezone

User = settings.AUTH_USER_MODEL


class Task(models.Model):
    OPEN, AWAITING, DONE, CANCELLED = "open", "awaiting_approval", "done", "cancelled"
    STATUSES = [(s, s) for s in (OPEN, AWAITING, DONE, CANCELLED)]
    PRIORITIES = [(p, p) for p in ("low", "normal", "high", "urgent")]
    MANUAL, CHECKLIST = "manual", "checklist"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    subject = models.OneToOneField("workspace.Subject", on_delete=models.PROTECT, related_name="task")
    project = models.ForeignKey("projects.Project", null=True, blank=True, on_delete=models.PROTECT,
                                related_name="tasks")
    column = models.ForeignKey("projects.BoardColumn", null=True, blank=True, on_delete=models.PROTECT,
                               related_name="tasks")
    customer = models.ForeignKey("crm.Customer", null=True, blank=True, on_delete=models.PROTECT,
                                 related_name="tasks")
    rank = models.BigIntegerField(default=0)
    title = models.CharField(max_length=200)
    description = models.JSONField(default=dict, blank=True)  # encrypted via workspace.textbox
    creator = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    status = models.CharField(max_length=20, choices=STATUSES, default=OPEN, db_index=True)
    priority = models.CharField(max_length=10, choices=PRIORITIES, default="normal")
    start_at = models.DateTimeField(null=True, blank=True)
    due_at = models.DateTimeField(null=True, blank=True)
    all_day = models.BooleanField(default=False)
    progress = models.PositiveSmallIntegerField(default=0)
    progress_mode = models.CharField(max_length=10, choices=[(MANUAL, MANUAL), (CHECKLIST, CHECKLIST)], default=MANUAL)
    weight = models.PositiveSmallIntegerField(default=1)  # 1-10; weight of its progress in the project average
    hidden = models.BooleanField(default=False, db_index=True)  # removal approved: only project managers still see it
    version = models.PositiveIntegerField(default=1)
    copied_from = models.ForeignKey("self", null=True, blank=True, on_delete=models.PROTECT, related_name="copies")
    completed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(default=timezone.now)


class TaskPerson(models.Model):
    OWNER, APPROVER, FOLLOWER = "owner", "approver", "follower"
    ROLES = [(r, r) for r in (OWNER, APPROVER, FOLLOWER)]
    APPROVED, REJECTED = "approved", "rejected"

    task = models.ForeignKey(Task, on_delete=models.PROTECT, related_name="people")
    user = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    role = models.CharField(max_length=10, choices=ROLES)
    position = models.PositiveSmallIntegerField(default=0)  # approvers decide serially in this order
    decision = models.CharField(max_length=10, blank=True, default="")
    decided_at = models.DateTimeField(null=True, blank=True)
    active = models.BooleanField(default=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["task", "user", "role"], name="one_row_per_task_user_role")]


class ChecklistItem(models.Model):
    task = models.ForeignKey(Task, on_delete=models.PROTECT, related_name="checklist")
    text = models.CharField(max_length=300)
    done = models.BooleanField(default=False)
    done_by = models.ForeignKey(User, null=True, blank=True, on_delete=models.PROTECT, related_name="+")
    done_at = models.DateTimeField(null=True, blank=True)
    rank = models.BigIntegerField(default=0)
    active = models.BooleanField(default=True)


class RemovalRequest(models.Model):
    """A request to remove a project task (needs a manager's decision when the project requires approval)."""

    PENDING, APPROVED, REJECTED = "pending", "approved", "rejected"
    STATUSES = [(s, s) for s in (PENDING, APPROVED, REJECTED)]

    task = models.ForeignKey(Task, on_delete=models.PROTECT, related_name="removal_requests")
    requested_by = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    note = models.JSONField(default=dict, blank=True)  # encrypted via workspace.textbox
    status = models.CharField(max_length=10, choices=STATUSES, default=PENDING, db_index=True)
    decided_by = models.ForeignKey(User, null=True, blank=True, on_delete=models.PROTECT, related_name="+")
    decision_note = models.JSONField(default=dict, blank=True)  # encrypted via workspace.textbox
    created_at = models.DateTimeField(default=timezone.now)
    decided_at = models.DateTimeField(null=True, blank=True)


class TaskTemplate(models.Model):
    """`owner` null = organisation template (manager only). `data` is validated by `tasks.templates`; the description
    inside it is stored encrypted."""

    owner = models.ForeignKey(User, null=True, blank=True, on_delete=models.PROTECT, related_name="+")
    name = models.CharField(max_length=100)
    data = models.JSONField(default=dict)
    active = models.BooleanField(default=True)
    created_at = models.DateTimeField(default=timezone.now)
