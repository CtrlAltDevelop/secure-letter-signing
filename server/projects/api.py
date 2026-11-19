"""Projects API (mounted at /api/projects). Rules live in rules.py, edits in service/columns, lists in views."""
from datetime import datetime
from uuid import UUID

from django.db.models import Q
from django.shortcuts import get_object_or_404
from ninja import File as UploadField
from ninja import Form, Query, Router
from ninja.errors import HttpError
from ninja.files import UploadedFile

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, user_of
from accounts.models import User
from workspace.seen import mark_seen

from . import columns, copying, files, rules, service, views
from .files import ProjectFileOut
from .imports import runner
from .imports.model import MAX_BYTES
from .imports.runner import ImportOut
from .models import Project, ProjectMember
from .schemas import (ColumnIn, ColumnOrder, ColumnOut, ColumnPatch, MemberIn, ProjectBrief, ProjectIn, ProjectOut,
                      ProjectPatch, ProjectTasksOut, ProjectCopyIn)
from .serializers import briefs, column_outs, project_out

router = Router(tags=["projects"], auth=BearerAuth())
ERRORS = {403: Detail, 404: Detail, 409: Detail, 422: Detail}
STATUS_VALUES = {Project.ACTIVE, Project.DONE, Project.ARCHIVED}


def _visible(user: User, project_id: UUID) -> Project:
    service.gate()
    project = get_object_or_404(Project.objects.select_related("subject"), pk=project_id)
    if not rules.can(user, project, "see"):
        raise HttpError(404, "Not found")
    return project


@router.post("", response={201: ProjectOut, **ERRORS})
def create(request, data: ProjectIn):
    service.gate()
    user = user_of(request)
    if not user.has_grant("project.create"):
        raise HttpError(403, "Permission denied")
    return 201, project_out(user, service.create_project(user, data))


@router.get("", response=list[ProjectBrief])
def list_projects(request, group: int | None = None, status: str = "", q: str = ""):
    service.gate()
    user = user_of(request)
    mine = ProjectMember.objects.filter(user=user, active=True).values("project_id")
    rows = Project.objects.filter(pk__in=mine).select_related("group")
    if group is not None:
        rows = rows.filter(group_id=group)
    wanted = {s for s in status.split(",") if s}
    if wanted:
        rows = rows.filter(status__in=wanted & STATUS_VALUES)
    if q.strip():
        rows = rows.filter(Q(name__icontains=q.strip()))
    return briefs(user, list(rows.order_by("-updated_at", "id")))


@router.get("/{uuid:project_id}", response={200: ProjectOut, 404: Detail})
def get_project(request, project_id: UUID):
    user = user_of(request)
    return project_out(user, _visible(user, project_id))


@router.patch("/{uuid:project_id}", response={200: ProjectOut, **ERRORS})
def patch(request, project_id: UUID, data: ProjectPatch):
    service.gate()
    user = user_of(request)
    return project_out(user, service.update_project(user, project_id, data))


@router.put("/{uuid:project_id}/members", response={200: ProjectOut, **ERRORS})
def put_members(request, project_id: UUID, data: list[MemberIn]):
    service.gate()
    user = user_of(request)
    return project_out(user, service.set_members(user, project_id, data))


@router.post("/{uuid:project_id}/copy", response={201: ProjectOut, **ERRORS})
def copy_project(request, project_id: UUID, data: ProjectCopyIn):
    user = user_of(request)
    return 201, project_out(user, copying.copy_project(user, project_id, data.name))


@router.post("/{uuid:project_id}/import", response={200: ImportOut, 403: Detail, 404: Detail, 409: Detail, 413: Detail,
                                                      422: Detail})
def import_tasks(request, project_id: UUID, format: Form[str], file: UploadedFile = UploadField(...)):
    """Manager only. `format`: trello (board JSON export), csv or xlsx; at most 5 MB and 2000 rows."""
    if file.size > MAX_BYTES:
        raise HttpError(413, "The file is larger than 5 MB")
    return runner.import_into_project(user_of(request), project_id, format.strip().lower(), file.read())


@router.get("/{uuid:project_id}/columns", response={200: list[ColumnOut], 404: Detail})
def list_columns(request, project_id: UUID):
    user = user_of(request)
    return column_outs(_visible(user, project_id))


@router.post("/{uuid:project_id}/columns", response={201: list[ColumnOut], **ERRORS})
def add_column(request, project_id: UUID, data: ColumnIn):
    service.gate()
    user = user_of(request)
    columns.add_column(user, project_id, data)
    return 201, column_outs(get_object_or_404(Project, pk=project_id))


@router.put("/{uuid:project_id}/columns/order", response={200: list[ColumnOut], **ERRORS})
def order_columns(request, project_id: UUID, data: ColumnOrder):
    service.gate()
    columns.reorder(user_of(request), project_id, data)
    return column_outs(get_object_or_404(Project, pk=project_id))


@router.patch("/{uuid:project_id}/columns/{int:column_id}", response={200: list[ColumnOut], **ERRORS})
def patch_column(request, project_id: UUID, column_id: int, data: ColumnPatch):
    service.gate()
    columns.patch_column(user_of(request), project_id, column_id, data)
    return column_outs(get_object_or_404(Project, pk=project_id))


@router.get("/{uuid:project_id}/files", response={200: list[ProjectFileOut], 404: Detail, 422: Detail})
def list_files(request, project_id: UUID, type: str = "", q: str = "", limit: int = 50, offset: int = 0):
    user = user_of(request)
    return files.project_files(user, _visible(user, project_id), type, q, limit, offset)


@router.get("/{uuid:project_id}/tasks", response={200: ProjectTasksOut, 404: Detail, 422: Detail})
def project_tasks(request, project_id: UUID, view: str = "board", from_: datetime | None = Query(None, alias="from"),
                  to: datetime | None = None, q: str = "", status: str = "", owner: int | None = None,
                  label: int | None = None, include_hidden: bool = False):
    user = user_of(request)
    project = _visible(user, project_id)
    mark_seen(user, project.subject)
    return views.project_tasks(user, project, view, from_, to, q, status, owner, label, include_hidden)
