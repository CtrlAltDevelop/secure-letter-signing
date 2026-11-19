"""Cached project progress: the weight-weighted average progress of its tasks, cancelled and removed ones excluded
(0 when none)."""
from django.db.models import F, Sum

from tasks.models import Task

from .models import Project


def compute(project_id) -> int:
    rows = Task.objects.filter(project_id=project_id, hidden=False).exclude(status=Task.CANCELLED)
    total = rows.aggregate(w=Sum("weight"), p=Sum(F("progress") * F("weight")))
    return round(total["p"] / total["w"]) if total["w"] else 0


def recompute(project_id) -> None:
    if project_id is not None:
        Project.objects.filter(pk=project_id).update(progress=compute(project_id))
