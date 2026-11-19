"""Create and edit projects, replace their members. Audit rows carry ids only, never names."""
from datetime import date
from uuid import UUID

from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja.errors import HttpError

from accounts import guests
from accounts.models import User, audit
from tasks import history
from workspace import registry
from workspace.models import Subject
from workspace.seen import mark_seen
from workspace.textbox import open_text, seal_text

from . import membership, notices, rules
from .models import BoardColumn, Project, ProjectGroup, ProjectMember
from .schemas import MemberIn, ProjectIn, ProjectPatch

RANK_GAP = 65_536
SETTINGS = ("members_can_edit_tasks", "members_can_extend", "require_removal_approval")
DEFAULT_COLUMNS = (("To do", BoardColumn.TODO), ("Doing", BoardColumn.DOING), ("Done", BoardColumn.DONE))


def gate() -> None:
    registry.require_module("projects")


def lock_project(user: User, project_id: UUID, action: str = "see") -> Project:
    """Project row locked for update: 404 unless the user is a member, 403 unless `action` is allowed."""
    project = get_object_or_404(Project.objects.select_for_update().select_related("subject"), pk=project_id)
    if not rules.can(user, project, "see"):
        raise HttpError(404, "Not found")
    if not rules.can(user, project, action):
        raise HttpError(403, "Permission denied")
    return project


def check_dates(start: date | None, end: date | None) -> None:
    if start and end and end < start:
        raise HttpError(422, "The end date is before the start date")


def checked_group(user: User, group_id: int | None) -> ProjectGroup | None:
    if group_id is None:
        return None
    group = ProjectGroup.objects.filter(pk=group_id, active=True).first()
    if group is None or (group.owner_id is not None and group.owner_id != user.id):
        raise HttpError(422, "Unknown group")
    return group


def checked_members(owner_id: int, members: list[MemberIn], actor: User) -> dict[int, str]:
    """{user_id: role} with the owner forced to manager; 422 for duplicates or unknown/inactive users."""
    wanted: dict[int, str] = {}
    for m in members:
        if m.user_id in wanted:
            raise HttpError(422, "A user appears twice in the member list")
        wanted[m.user_id] = m.role
    if wanted.get(owner_id, membership.MANAGER) != membership.MANAGER:
        raise HttpError(422, "The owner cannot be demoted")
    wanted[owner_id] = membership.MANAGER
    if User.objects.filter(pk__in=wanted, is_active=True).count() != len(wanted) or guests.referable_ids(actor, wanted) != set(wanted):
        raise HttpError(422, "Unknown or inactive user")
    return wanted


def check_owner_kept(owner_id: int, members: list[MemberIn]) -> None:
    """A full member list for an existing project must still contain its owner."""
    if all(m.user_id != owner_id for m in members):
        raise HttpError(422, "The owner cannot be removed")


@transaction.atomic
def create_project(user: User, data: ProjectIn) -> Project:
    check_dates(data.start_date, data.end_date)
    group = checked_group(user, data.group_id)
    wanted = checked_members(user.id, data.members, user)
    subject = Subject.objects.create(module=notices.MODULE, kind="project")
    description = seal_text(data.description.text if data.description else "")
    project = Project.objects.create(
        subject=subject, name=data.name.strip(), description=description, group=group, color=data.color,
        owner=user, start_date=data.start_date, end_date=data.end_date,
        members_can_edit_tasks=data.members_can_edit_tasks, members_can_extend=data.members_can_extend,
        require_removal_approval=data.require_removal_approval)
    ProjectMember.objects.bulk_create([ProjectMember(project=project, user_id=uid, role=role, added_by=user)
                                       for uid, role in wanted.items()])
    BoardColumn.objects.bulk_create([BoardColumn(project=project, title=t, kind=k, rank=(i + 1) * RANK_GAP)
                                     for i, (t, k) in enumerate(DEFAULT_COLUMNS)])
    history.log(subject, user, "status", None, Project.ACTIVE)
    audit(user, "project_created", str(project.id))
    mark_seen(user, subject)
    notices.emit_project("project.created", project, user)
    notices.notify_added(wanted, project, user)
    return project


def _scalar_changes(project: Project, data: ProjectPatch, fields: set[str], user: User) -> dict:
    changes = {}
    for name in ("name", "color", "status", "start_date", "end_date", *SETTINGS):
        if name not in fields:
            continue
        value = getattr(data, name)
        if name == "name" and value is not None:
            value = value.strip()
        if value is None and name in ("name", "color", "status", *SETTINGS):
            raise HttpError(422, f"{name} cannot be empty")
        if getattr(project, name) != value:
            changes[name] = (getattr(project, name), value)
            setattr(project, name, value)
    if "group_id" in fields:
        group = checked_group(user, data.group_id)
        if project.group_id != (group.id if group else None):
            changes["group_id"] = (project.group_id, group.id if group else None)
            project.group = group
    return changes


@transaction.atomic
def update_project(user: User, project_id: UUID, data: ProjectPatch) -> Project:
    project = lock_project(user, project_id, "edit")
    fields = data.model_fields_set
    changes = _scalar_changes(project, data, fields, user)
    check_dates(project.start_date, project.end_date)
    if "description" in fields:
        new_text = data.description.text if data.description else ""
        if new_text != open_text(project.description):
            project.description = seal_text(new_text)
            changes["description"] = (None, None)
    if changes:
        project.updated_at = timezone.now()
        project.save()
        history.log_all(project.subject, user, changes)
        notices.emit_project("project.updated", project, user, fields=sorted(changes))
    mark_seen(user, project.subject)
    return project


def _members_state(project: Project) -> dict[int, str]:
    return dict(ProjectMember.objects.filter(project=project, active=True).values_list("user_id", "role"))


def _sync_members(project: Project, wanted: dict[int, str], actor: User) -> None:
    """Make exactly `wanted` the active members; others are deactivated, never deleted."""
    rows = {m.user_id: m for m in ProjectMember.objects.filter(project=project)}
    for uid, role in wanted.items():
        row = rows.get(uid)
        if row is None:
            ProjectMember.objects.create(project=project, user_id=uid, role=role, added_by=actor)
        elif not row.active or row.role != role:
            if not row.active:
                row.added_by, row.at = actor, timezone.now()
            row.active, row.role = True, role
            row.save()
    for uid, row in rows.items():
        if uid not in wanted and row.active:
            row.active = False
            row.save(update_fields=["active"])


@transaction.atomic
def set_members(user: User, project_id: UUID, members: list[MemberIn]) -> Project:
    project = lock_project(user, project_id, "edit")
    check_owner_kept(project.owner_id, members)
    wanted = checked_members(project.owner_id, members, user)
    before = _members_state(project)
    if before == wanted:
        return project
    _sync_members(project, wanted, user)
    added = sorted(set(wanted) - set(before))
    history.log(project.subject, user, "members", sorted(before.items()), sorted(wanted.items()))
    project.updated_at = timezone.now()
    project.save(update_fields=["updated_at"])
    audit(user, "project_members_changed", str(project.id), added=len(added), total=len(wanted))
    if added:
        notices.emit_project("project.member.added", project, user, user_ids=added)
        notices.notify_added(added, project, user)
    notices.emit_project("project.updated", project, user, fields=["members"])
    return project
