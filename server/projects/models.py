"""Projects, members, board columns and groups. Nothing is deleted (DB triggers); description is encrypted at rest."""
import uuid

from django.conf import settings
from django.db import models
from django.utils import timezone

User = settings.AUTH_USER_MODEL


class ProjectGroup(models.Model):
    """A folder for the project list: organisation-wide (owner null, manager-run) or personal (owner = the user)."""

    name = models.CharField(max_length=100)
    owner = models.ForeignKey(User, null=True, blank=True, on_delete=models.PROTECT, related_name="+")
    rank = models.BigIntegerField(default=0)
    active = models.BooleanField(default=True)


class Project(models.Model):
    ACTIVE, DONE, ARCHIVED = "active", "done", "archived"
    STATUSES = [(s, s) for s in (ACTIVE, DONE, ARCHIVED)]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    subject = models.OneToOneField("workspace.Subject", on_delete=models.PROTECT, related_name="project")
    name = models.CharField(max_length=200)
    description = models.JSONField(default=dict, blank=True)  # encrypted via workspace.textbox
    group = models.ForeignKey(ProjectGroup, null=True, blank=True, on_delete=models.PROTECT, related_name="projects")
    color = models.PositiveSmallIntegerField(default=0)
    status = models.CharField(max_length=10, choices=STATUSES, default=ACTIVE, db_index=True)
    owner = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    start_date = models.DateField(null=True, blank=True)
    end_date = models.DateField(null=True, blank=True)
    progress = models.PositiveSmallIntegerField(default=0)  # cached: weighted average task progress, cancelled excluded
    # Settings: what plain members (not managers) may do with tasks.
    members_can_edit_tasks = models.BooleanField(default=True)  # create tasks and edit their fields and people
    members_can_extend = models.BooleanField(default=True)  # move a due date later than it is now
    require_removal_approval = models.BooleanField(default=False)  # removing a task needs a manager's approval
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(default=timezone.now)


class ProjectMember(models.Model):
    MANAGER, MEMBER, VIEWER = "manager", "member", "viewer"
    ROLES = [(r, r) for r in (MANAGER, MEMBER, VIEWER)]

    project = models.ForeignKey(Project, on_delete=models.PROTECT, related_name="members")
    user = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    role = models.CharField(max_length=10, choices=ROLES, default=MEMBER)
    active = models.BooleanField(default=True)
    added_by = models.ForeignKey(User, null=True, on_delete=models.PROTECT, related_name="+")
    at = models.DateTimeField(default=timezone.now)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["project", "user"], name="one_member_row_per_project_user")]


class BoardColumn(models.Model):
    TODO, DOING, DONE = "todo", "doing", "done"
    KINDS = [(k, k) for k in (TODO, DOING, DONE)]

    project = models.ForeignKey(Project, on_delete=models.PROTECT, related_name="columns")
    title = models.CharField(max_length=100)
    rank = models.BigIntegerField(default=0)
    kind = models.CharField(max_length=10, choices=KINDS, default=DOING)
    active = models.BooleanField(default=True)
