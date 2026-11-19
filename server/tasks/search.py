"""Unified search for tasks: title and the caller's labels."""
from django.db.models import Q

from accounts.models import User
from workspace.access import visible_labels
from workspace.models import SubjectLabel
from workspace.search import hit

from .queries import visible_tasks


def search(user: User, q: str, limit: int) -> list[dict]:
    labels = visible_labels(user).filter(active=True, name__icontains=q).values("pk")
    labelled = SubjectLabel.objects.filter(active=True, label__in=labels).values("subject_id")
    rows = (visible_tasks(user).filter(hidden=False).filter(Q(title__icontains=q) | Q(subject_id__in=labelled))
            .order_by("-updated_at", "id")[:limit])
    return [hit("tasks", "task", t.id, t.subject_id, t.title, t.status, t.updated_at) for t in rows]
