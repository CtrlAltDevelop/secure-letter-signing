"""Who may see and edit a project's Gantt plan. Viewers read; managers edit; members edit only when the project
lets members edit tasks (`members_can_edit_tasks`). Everything is built on projects/membership.py."""
from uuid import UUID

from django.shortcuts import get_object_or_404
from ninja.errors import HttpError

from accounts.models import User
from projects import membership
from projects.models import Project
from workspace import registry


def gate() -> None:
    registry.require_module("projects")
    registry.require_module("gantt")


def can_edit(user: User, project: Project) -> bool:
    role = membership.role_in(user, project.pk)
    return role == membership.MANAGER or (role == membership.MEMBER and project.members_can_edit_tasks)


def visible(user: User, project_id: UUID) -> Project:
    """404 unless the user is an active member of the project."""
    gate()
    project = get_object_or_404(Project.objects.select_related("subject"), pk=project_id)
    if membership.role_in(user, project.pk) is None:
        raise HttpError(404, "Not found")
    return project


def editable(user: User, project_id: UUID) -> Project:
    """Project row locked for update; 404 for non-members, 403 for viewers (and members when not allowed)."""
    gate()
    project = get_object_or_404(Project.objects.select_for_update().select_related("subject"), pk=project_id)
    if membership.role_in(user, project.pk) is None:
        raise HttpError(404, "Not found")
    if not can_edit(user, project):
        raise HttpError(403, "Permission denied")
    return project
