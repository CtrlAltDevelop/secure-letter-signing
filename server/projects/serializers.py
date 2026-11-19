"""Project -> ProjectBrief / ProjectOut."""
from collections.abc import Sequence

from django.db.models import Count

from accounts.models import User
from workspace.schemas import user_ref
from workspace.textbox import open_text

from . import rules
from .models import BoardColumn, Project, ProjectMember
from .schemas import CanOut, ColumnOut, DescriptionOut, MemberOut, ProjectBrief, ProjectOut

ACTIONS = ("see", "comment", "label", "edit", "moderate", "create_task")


def _shown_group_id(user: User, project: Project) -> int | None:
    """A personal group is private to its owner: others see no group."""
    group = project.group
    return group.id if group and (group.owner_id is None or group.owner_id == user.id) else None


def briefs(user: User, projects: Sequence[Project]) -> list[ProjectBrief]:
    counts = dict(ProjectMember.objects.filter(project__in=projects, active=True).values_list("project_id")
                  .annotate(n=Count("id")))
    roles = dict(ProjectMember.objects.filter(project__in=projects, user=user, active=True)
                 .values_list("project_id", "role"))
    return [ProjectBrief(
        id=p.id, subject_id=p.subject_id, name=p.name, color=p.color, status=p.status,
        group_id=_shown_group_id(user, p), owner_id=p.owner_id, progress=p.progress, start_date=p.start_date,
        end_date=p.end_date, my_role=roles.get(p.id, ""), member_count=counts.get(p.id, 0), updated_at=p.updated_at)
        for p in projects]


def column_outs(project: Project) -> list[ColumnOut]:
    counts = {r["column_id"]: r["n"] for r in project.tasks.filter(hidden=False).values("column_id").annotate(n=Count("id"))}
    rows = BoardColumn.objects.filter(project=project, active=True).order_by("rank", "id")
    return [ColumnOut(id=c.id, title=c.title, kind=c.kind, rank=c.rank, task_count=counts.get(c.id, 0)) for c in rows]


def project_out(user: User, project: Project) -> ProjectOut:
    project = Project.objects.select_related("subject", "owner", "group").get(pk=project.pk)
    members = ProjectMember.objects.filter(project=project, active=True).select_related("user").order_by("at", "id")
    return ProjectOut(
        **briefs(user, [project])[0].model_dump(),
        members_can_edit_tasks=project.members_can_edit_tasks, members_can_extend=project.members_can_extend,
        require_removal_approval=project.require_removal_approval,
        description=DescriptionOut(text=open_text(project.description)), owner=user_ref(project.owner),
        members=[MemberOut(user=user_ref(m.user), role=m.role) for m in members], columns=column_outs(project),
        can=CanOut(**{a: rules.can(user, project, a) for a in ACTIONS}), created_at=project.created_at)
