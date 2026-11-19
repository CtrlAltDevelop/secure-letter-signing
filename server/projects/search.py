"""Unified search for projects the caller is a member of."""
from accounts.models import User
from workspace.search import hit

from .models import Project, ProjectMember


def search(user: User, q: str, limit: int) -> list[dict]:
    mine = ProjectMember.objects.filter(user=user, active=True).values("project_id")
    rows = Project.objects.filter(pk__in=mine, name__icontains=q).order_by("-updated_at", "id")[:limit]
    return [hit("projects", "project", p.id, p.subject_id, p.name, p.status, p.updated_at) for p in rows]
