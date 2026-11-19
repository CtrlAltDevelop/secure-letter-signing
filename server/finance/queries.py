"""Filters for the document list."""
from datetime import date
from uuid import UUID

from django.db.models import Q, QuerySet

from accounts.models import User
from workspace.access import visible_labels
from workspace.models import SubjectLabel
from workspace.textbox import open_text

from . import reports
from .models import FinanceDoc

MAX_LIMIT = 200
DESCRIPTION_SCAN = 500  # the description is encrypted: only the latest rows are searched for `q`


def _csv(value: str) -> list[str]:
    return [v for v in value.split(",") if v]


def _search(rows: QuerySet[FinanceDoc], text: str) -> QuerySet[FinanceDoc]:
    query = Q(customer__name__icontains=text) | Q(customer__legal_name__icontains=text)
    if text.isdigit():
        query |= Q(amount=int(text))
    hits = {d.pk for d in rows.order_by("-date", "-created_at")[:DESCRIPTION_SCAN] if text.lower() in
            open_text(d.description).lower()}
    return rows.filter(query | Q(pk__in=hits))


def filtered(user: User, rows: QuerySet[FinanceDoc], *, customer: UUID | None, kind: str, direction: str,
             status: str, label: int | None, start: date | None, end: date | None, q: str) -> QuerySet[FinanceDoc]:
    if customer is not None:
        rows = rows.filter(customer_id=customer)
    if kind:
        rows = rows.filter(kind__in=_csv(kind))
    if direction:
        rows = rows.filter(direction=direction)
    if status:
        rows = rows.filter(status__in=_csv(status))
    if label is not None:
        ok = visible_labels(user).filter(pk=label, active=True).exists()
        tagged = SubjectLabel.objects.filter(label_id=label, active=True).values("subject_id") if ok else []
        rows = rows.filter(subject_id__in=tagged)
    if start or end:
        rows = reports.with_effective_date(rows)
        rows = rows.filter(effective_date__gte=start) if start else rows
        rows = rows.filter(effective_date__lte=end) if end else rows
    return _search(rows, q.strip()) if q.strip() else rows


def page(rows: QuerySet[FinanceDoc], limit: int, offset: int) -> list[FinanceDoc]:
    start = max(offset, 0)
    ordered = rows.select_related("subject", "customer", "created_by", "voided_by").order_by("-date", "-created_at")
    return list(ordered[start : start + max(min(limit, MAX_LIMIT), 0)])
