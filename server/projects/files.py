"""`GET /projects/{id}/files`: every active file of the project's visible tasks plus the project's own files."""
from datetime import datetime
from uuid import UUID

from django.db.models import Q, QuerySet
from ninja import Schema
from ninja.errors import HttpError

from accounts.models import User
from tasks.models import Task
from workspace.models import File
from workspace.schemas import UserRef, user_ref

from . import membership
from .models import Project

MAX_LIMIT = 200
TYPES = ("image", "video", "document")


class ProjectFileOut(Schema):
    id: UUID
    name: str
    content_type: str
    size: int
    task_id: UUID | None
    task_title: str | None
    uploaded_by: UserRef
    created_at: datetime


def _of_type(rows: QuerySet[File], kind: str) -> QuerySet[File]:
    if not kind:
        return rows
    if kind not in TYPES:
        raise HttpError(422, "type must be image, video or document")
    media = Q(content_type__startswith="image/") | Q(content_type__startswith="video/")
    if kind == "document":
        return rows.exclude(media)
    return rows.filter(content_type__startswith=f"{kind}/")


def project_files(user: User, project: Project, kind: str, q: str, limit: int, offset: int) -> list[ProjectFileOut]:
    tasks = Task.objects.filter(project=project)
    if membership.role_in(user, project.pk) != membership.MANAGER:
        tasks = tasks.filter(hidden=False)
    titles = {t.subject_id: (t.id, t.title) for t in tasks.only("id", "title", "subject_id")}
    rows = File.objects.filter(active=True).filter(Q(subject_id__in=list(titles)) | Q(subject_id=project.subject_id))
    rows = _of_type(rows, kind)
    if q.strip():
        rows = rows.filter(name__icontains=q.strip())
    start = max(offset, 0)
    page = rows.select_related("uploaded_by", "uploaded_by__org_title").order_by("-created_at", "-id")
    out = []
    for f in page[start : start + max(min(limit, MAX_LIMIT), 0)]:
        task_id, title = titles.get(f.subject_id, (None, None))
        out.append(ProjectFileOut(id=f.id, name=f.name, content_type=f.content_type, size=f.size, task_id=task_id,
                                  task_title=title, uploaded_by=user_ref(f.uploaded_by), created_at=f.created_at))
    return out
