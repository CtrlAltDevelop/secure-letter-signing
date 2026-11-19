"""Who may do what with a project (registry `can`). The owner is always a manager member."""
from accounts.models import User

from . import membership
from .models import Project

ANY_MEMBER = {"see", "comment"}
WORKERS = {"label", "create_task"}
MANAGER_ONLY = {"edit", "moderate"}


def can(user: User, project: Project, action: str) -> bool:
    role = membership.role_in(user, project.pk)
    if role is None:
        return False
    if action in ANY_MEMBER:
        return True
    if action in WORKERS:
        return role in membership.CAN_WORK
    return action in MANAGER_ONLY and role == membership.MANAGER


def audience(project: Project) -> set[int]:
    return membership.member_ids(project.pk)
