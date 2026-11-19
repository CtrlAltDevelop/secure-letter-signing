"""`ModuleSpec.stats` callbacks of tasks, projects, letters and meetings. Aggregates only: the oversight holder sees
counts and dates, never text. Each returns `{"totals": {...}, "series": {name: [{date, value}]}}`."""
from datetime import datetime

from django.db.models import Count, Q
from django.utils import timezone

from accounts.models import User
from letters.models import Letter, Signature
from meetings.models import Meeting
from projects.models import Project
from tasks.models import Task

from .period import daily, from_bounds, total

ACTIVE = (Task.OPEN, Task.AWAITING)


def tasks(user: User, start: datetime, end: datetime) -> dict:
    period = from_bounds(start, end)
    rows = Task.objects.filter(hidden=False).exclude(status=Task.CANCELLED)
    now = timezone.now()
    active = rows.filter(status__in=ACTIVE)
    created = daily(rows, "created_at", period)
    completed = daily(rows.filter(status=Task.DONE), "completed_at", period)
    overdue = daily(active.filter(due_at__lt=now), "due_at", period)
    now_counts = active.aggregate(active=Count("pk"), overdue=Count("pk", filter=Q(due_at__lt=now)))
    return {"totals": {"created": total(created), "completed": total(completed), "overdue_started": total(overdue),
                       "active": now_counts["active"], "overdue_now": now_counts["overdue"]},
            "series": {"created": created, "completed": completed, "overdue": overdue}}


def projects(user: User, start: datetime, end: datetime) -> dict:
    period = from_bounds(start, end)
    created = daily(Project.objects.all(), "created_at", period)
    by_status = dict(Project.objects.order_by().values_list("status").annotate(n=Count("pk")))
    statuses = {s: by_status.get(s, 0) for s in (Project.ACTIVE, Project.DONE, Project.ARCHIVED)}
    return {"totals": {"created": total(created), "all": sum(by_status.values()), **statuses},
            "series": {"created": created}}


def letters(user: User, start: datetime, end: datetime) -> dict:
    period = from_bounds(start, end)
    rows = Letter.objects.exclude(status=Letter.DRAFT)  # drafts are private to their creator
    created = daily(rows, "created_at", period)
    signed = daily(Signature.objects.filter(decision="approved"), "created_at", period)
    return {"totals": {"created": total(created), "signed": total(signed),
                       "in_signing": rows.filter(status=Letter.IN_SIGNING).count()},
            "series": {"created": created, "signed": signed}}


def meetings(user: User, start: datetime, end: datetime) -> dict:
    period = from_bounds(start, end)
    rows = Meeting.objects.exclude(status=Meeting.DRAFT).filter(starts_at__isnull=False)
    held = daily(rows.exclude(status=Meeting.CANCELLED), "starts_at", period)
    in_period = rows.filter(starts_at__gte=period.start, starts_at__lt=period.end)
    by_status = dict(in_period.order_by().values_list("status").annotate(n=Count("pk")))
    return {"totals": {"meetings": total(held), "by_status": by_status}, "series": {"meetings": held}}
