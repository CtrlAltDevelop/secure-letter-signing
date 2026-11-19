"""Work transfer for projects: the source's memberships and ownerships move to the target."""
from django.utils import timezone

from accounts.models import User
from tasks import history

from . import membership, notices
from .models import ProjectMember

RANK = {membership.VIEWER: 0, membership.MEMBER: 1, membership.MANAGER: 2}


def _target_role(source: ProjectMember, target: ProjectMember | None, owner: bool) -> str:
    if owner:
        return membership.MANAGER
    roles = [source.role] + ([target.role] if target and target.active else [])
    return max(roles, key=RANK.__getitem__)


def _give(project, to_user: User, role: str, actor: User, target: ProjectMember | None) -> None:
    if target is None:
        ProjectMember.objects.create(project=project, user=to_user, role=role, added_by=actor)
        return
    if not target.active:
        target.added_by, target.at = actor, timezone.now()
    target.active, target.role = True, role
    target.save()


def transfer(from_user: User, to_user: User, actor: User) -> int:
    """Move every active membership (ownership included) from `from_user` to `to_user`; returns the project count."""
    rows = ProjectMember.objects.select_for_update().filter(user=from_user, active=True).select_related("project")
    moved = 0
    for row in rows:
        project = row.project
        target = ProjectMember.objects.filter(project=project, user=to_user).first()
        owner = project.owner_id == from_user.id
        _give(project, to_user, _target_role(row, target, owner), actor, target)
        row.active = False
        row.save(update_fields=["active"])
        if owner:
            project.owner = to_user
        project.updated_at = timezone.now()
        project.save()
        history.log(project.subject, actor, "transfer", {"from": from_user.id}, {"to": to_user.id, "owner": owner})
        notices.emit_project("project.updated", project, actor, fields=["members"])
        moved += 1
    return moved
