"""`GET /monitor/customers`: customer-file monitoring. Names are plaintext briefs; notes, addresses and timeline
summaries (encrypted) are never read."""
from datetime import timedelta

from django.db.models import Count, Max, Q
from django.utils import timezone

from crm.models import Customer
from tasks.models import Task

from .period import Period

QUIET_DAYS = 30
MAX_LIMIT = 200


def report(period: Period, limit: int, offset: int) -> dict:
    now = timezone.now()
    active = Q(tasks__status__in=(Task.OPEN, Task.AWAITING), tasks__hidden=False)
    rows = (Customer.objects.exclude(status=Customer.ARCHIVED)
            .annotate(last_event=Max("events__at"), open_tasks=Count("tasks", filter=active, distinct=True),
                      overdue_tasks=Count("tasks", filter=active & Q(tasks__due_at__lt=now), distinct=True))
            .order_by("last_event", "id"))  # the quietest files first
    by_status = dict(Customer.objects.order_by().values_list("status").annotate(n=Count("pk")))
    quiet_since = now - timedelta(days=QUIET_DAYS)
    page = rows[max(offset, 0):max(offset, 0) + max(min(limit, MAX_LIMIT), 0)]
    return {**period.header(), "total": sum(by_status.values()), "by_status": by_status,
            "created_in_period": Customer.objects.filter(created_at__gte=period.start, created_at__lt=period.end).count(),
            "quiet_days": QUIET_DAYS,
            "quiet": rows.filter(Q(last_event__lt=quiet_since) | Q(last_event__isnull=True), status=Customer.ACTIVE).count(),
            "customers": [{"id": str(c.id), "name": c.name, "kind": c.kind, "status": c.status,
                           "last_event_at": c.last_event, "open_tasks": c.open_tasks,
                           "overdue_tasks": c.overdue_tasks} for c in page]}
