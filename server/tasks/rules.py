"""Who may do what with a task. One place, used by every endpoint and by the workspace registry (`can`)."""
from accounts.models import User
from projects import membership

from .models import Task, TaskPerson

CREATOR = "creator"
SEE_ACTIONS = {"see", "comment", "label"}  # anyone involved in the task
# Actions only valid in some states: role fine but wrong state -> 409 instead of 403.
STATE_RULES = {
    "edit": {Task.OPEN, Task.AWAITING},
    "progress": {Task.OPEN},
    "complete": {Task.OPEN},
    "approve": {Task.AWAITING},
    "reopen": {Task.DONE, Task.CANCELLED},
}  # "move" has no state rule: finished tasks can still be dragged between columns


def roles_of(user: User, task: Task) -> set[str]:
    """`creator` plus the user's active TaskPerson roles."""
    roles = set(TaskPerson.objects.filter(task=task, user=user, active=True).values_list("role", flat=True))
    if task.creator_id == user.id:
        roles.add(CREATOR)
    return roles


def current_approver_id(task: Task) -> int | None:
    """Serial approval: the first active approver (by position) who has not decided yet."""
    row = (TaskPerson.objects.filter(task=task, role=TaskPerson.APPROVER, active=True, decision="")
           .order_by("position", "id").first())
    return row.user_id if row else None


def _role_ok(action: str, roles: set[str], project_role: str | None = None, project=None) -> bool:
    manager = project_role == membership.MANAGER
    if action in SEE_ACTIONS:
        return bool(roles) or project_role is not None
    if action in ("edit", "reopen", "moderate", "move"):
        if manager:
            return True
        locked = action == "edit" and project_role == membership.MEMBER and not project.members_can_edit_tasks
        return CREATOR in roles and not locked
    if action == "request_removal":
        return project_role is not None and bool(roles & {CREATOR, TaskPerson.OWNER})
    if action == "decide_removal":
        return manager
    if action in ("progress", "complete"):
        return TaskPerson.OWNER in roles
    if action == "approve":
        return TaskPerson.APPROVER in roles
    return False


def denial(user: User, task: Task, action: str) -> int | None:
    """None when allowed; 409 when the role fits but the task state does not; 403 otherwise."""
    project_role = membership.role_in(user, task.project_id) if task.project_id else None
    if task.project_id and project_role is None:
        return 403  # a project task belongs to the project's active members only
    if task.hidden and project_role != membership.MANAGER:
        return 403  # a removed task is visible to the project's managers only
    roles = roles_of(user, task)
    if not _role_ok(action, roles, project_role, task.project if task.project_id else None):
        return 403
    if action == "request_removal" and not task.project.require_removal_approval:
        return 409  # without the setting the creator or a manager just cancels the task
    states = STATE_RULES.get(action)
    if states is None:
        return None
    if task.status not in states or (action == "approve" and current_approver_id(task) != user.id):
        return 409
    return None


def may_extend(user: User, task: Task) -> bool:
    """False for a plain project member when the project forbids moving due dates later."""
    if not task.project_id:
        return True
    project = task.project
    return project.members_can_extend or membership.role_in(user, project.pk) == membership.MANAGER


def can(user: User, task: Task, action: str) -> bool:
    return denial(user, task, action) is None


def audience(task: Task) -> set[int]:
    """Every active project member for a project task, else the creator plus every active person on the task."""
    if task.project_id:
        return membership.member_ids(task.project_id)
    ids = set(TaskPerson.objects.filter(task=task, active=True).values_list("user_id", flat=True))
    ids.add(task.creator_id)
    return ids
