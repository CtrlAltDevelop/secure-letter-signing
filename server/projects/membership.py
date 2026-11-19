"""Who is in a project. Imported by tasks.rules, so it must not import the tasks app."""
from accounts.models import User

from .models import ProjectMember

MANAGER, MEMBER, VIEWER = ProjectMember.MANAGER, ProjectMember.MEMBER, ProjectMember.VIEWER
CAN_WORK = {MANAGER, MEMBER}  # may create tasks and move cards in


def role_in(user: User, project_id) -> str | None:
    """The user's active role in the project, or None (also for the company manager: no automatic access)."""
    return (ProjectMember.objects.filter(project_id=project_id, user=user, active=True)
            .values_list("role", flat=True).first())


def manager_ids(project_id) -> set[int]:
    return set(ProjectMember.objects.filter(project_id=project_id, active=True, role=MANAGER, user__is_active=True)
               .values_list("user_id", flat=True))


def member_ids(project_id) -> set[int]:
    return set(ProjectMember.objects.filter(project_id=project_id, active=True, user__is_active=True)
               .values_list("user_id", flat=True))
