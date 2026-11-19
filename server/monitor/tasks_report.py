"""`GET /monitor/tasks`: counts by status plus the overdue report (who, what, how late). Titles are plaintext briefs;
descriptions, comments and checklists are never read here."""
from django.db.models import Count, F, Q, QuerySet
from django.utils import timezone

from tasks.models import Task, TaskPerson
from workspace.schemas import user_ref

PRINT_LIMIT = 2000
MAX_LIMIT = 200


def filtered(project: str, label: int | None, person: int | None, customer: str) -> QuerySet:
    rows = Task.objects.filter(hidden=False)
    if project:
        rows = rows.filter(project_id=project) if project != "none" else rows.filter(project__isnull=True)
    if customer:
        rows = rows.filter(customer_id=customer)
    if person is not None:
        rows = rows.filter(people__user_id=person, people__role=TaskPerson.OWNER, people__active=True)
    if label is not None:
        rows = rows.filter(subject__subject_labels__label_id=label, subject__subject_labels__active=True)
    return rows.distinct()


def _row(task: Task, now) -> dict:
    owners = [user_ref(p.user).model_dump() for p in task.people.all() if p.role == TaskPerson.OWNER and p.active]
    late = now - task.due_at
    return {"id": str(task.id), "title": task.title, "priority": task.priority, "status": task.status,
            "due_at": task.due_at, "days_late": late.days, "hours_late": int(late.total_seconds() // 3600),
            "project_id": str(task.project_id) if task.project_id else None,
            "project_name": task.project.name if task.project_id else "",
            "customer_id": str(task.customer_id) if task.customer_id else None,
            "customer_name": task.customer.name if task.customer_id else "", "owners": owners,
            "creator": user_ref(task.creator).model_dump()}


def report(rows: QuerySet, limit: int, offset: int, printable: bool) -> dict:
    now = timezone.now()
    counts = dict(rows.order_by().values_list("status").annotate(n=Count("pk", distinct=True)))
    overdue_qs = rows.filter(status__in=(Task.OPEN, Task.AWAITING), due_at__lt=now)
    total = overdue_qs.count()
    cap = PRINT_LIMIT if printable else max(min(limit, MAX_LIMIT), 0)
    start = 0 if printable else max(offset, 0)
    page = (overdue_qs.select_related("project", "customer", "creator").prefetch_related("people__user__org_title")
            .order_by(F("due_at").asc(), "id")[start:start + cap])
    by_status = {s: counts.get(s, 0) for s in (Task.OPEN, Task.AWAITING, Task.DONE, Task.CANCELLED)}
    return {"generated_at": now, "by_status": by_status, "total": sum(by_status.values()), "overdue_total": total,
            "overdue": [_row(t, now) for t in page], "printable": printable}
