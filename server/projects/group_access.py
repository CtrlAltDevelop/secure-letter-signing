"""`PUT /project-groups/{id}/access`: the company manager changes who may access every project of an organisation
group. Rows are added or deactivated through `service._sync_members`, never deleted; project owners stay managers."""
from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja.errors import HttpError

from accounts import guests
from accounts.models import User, audit
from tasks import history

from . import notices, service
from .models import Project, ProjectGroup
from .schemas import GroupAccessIn


@transaction.atomic
def apply(actor: User, group_id: int, data: GroupAccessIn) -> dict:
    group = get_object_or_404(ProjectGroup.objects.filter(owner__isnull=True), pk=group_id)  # org groups only
    add = {m.user_id: m.role for m in data.add}
    if len(add) != len(data.add) or set(add) & set(data.remove):
        raise HttpError(422, "A user appears twice or in both lists")
    ids = set(add)
    if User.objects.filter(pk__in=ids, is_active=True).count() != len(ids) or guests.referable_ids(actor, ids) != ids:
        raise HttpError(422, "Unknown or inactive user")
    projects = Project.objects.select_for_update().filter(group=group).exclude(status=Project.ARCHIVED).order_by("id")
    changed = 0
    for project in projects:
        before = service._members_state(project)
        wanted = {uid: role for uid, role in before.items() if uid not in data.remove or uid == project.owner_id}
        wanted.update({uid: role for uid, role in add.items() if uid != project.owner_id})
        if wanted == before:
            continue
        service._sync_members(project, wanted, actor)
        history.log(project.subject, actor, "members", sorted(before.items()), sorted(wanted.items()))
        project.updated_at = timezone.now()
        project.save(update_fields=["updated_at"])
        newly = sorted(set(wanted) - set(before))
        audit(actor, "project_members_changed", str(project.id), added=len(newly), total=len(wanted))
        if newly:
            notices.emit_project("project.member.added", project, actor, user_ids=newly)
            notices.notify_added(newly, project, actor)
        notices.emit_project("project.updated", project, actor, fields=["members"])
        changed += 1
    audit(actor, "project_group_access_changed", str(group.id), added=len(add), removed=len(data.remove), projects=changed)
    return {"group_id": group.id, "projects_changed": changed}
