"""Filters for the lead list and the probability buckets."""
from django.db.models import Q, QuerySet

from accounts.models import User
from workspace.access import visible_labels
from workspace.models import SubjectLabel

from .models import Lead

MAX_LIMIT = 200
BUCKETS = (("0-24", 0, 24), ("25-49", 25, 49), ("50-74", 50, 74), ("75-100", 75, 100))
BUCKET_RANGES = {name: (low, high) for name, low, high in BUCKETS}


def _csv(value: str) -> list[str]:
    return [v for v in value.split(",") if v]


def filtered(user: User, rows: QuerySet[Lead], *, owner: int | None, customer, status: str, label: int | None,
             min_prob: int | None, max_prob: int | None, q: str, bucket: str) -> QuerySet[Lead]:
    if owner is not None:
        rows = rows.filter(owner_id=owner)
    if customer is not None:
        rows = rows.filter(customer_id=customer)
    if status:
        rows = rows.filter(status__in=_csv(status))
    if label is not None:
        ok = visible_labels(user).filter(pk=label, active=True).exists()
        tagged = SubjectLabel.objects.filter(label_id=label, active=True).values("subject_id") if ok else []
        rows = rows.filter(subject_id__in=tagged)
    if bucket in BUCKET_RANGES:
        low, high = BUCKET_RANGES[bucket]
        min_prob, max_prob = max(low, min_prob or 0), min(high, max_prob if max_prob is not None else 100)
        rows = rows if status else rows.filter(status=Lead.OPEN)
    if min_prob is not None:
        rows = rows.filter(probability__gte=min_prob)
    if max_prob is not None:
        rows = rows.filter(probability__lte=max_prob)
    if q.strip():
        rows = rows.filter(Q(title__icontains=q.strip()) | Q(customer__name__icontains=q.strip()))
    return rows


def page(rows: QuerySet[Lead], limit: int, offset: int) -> list[Lead]:
    start = max(offset, 0)
    ordered = rows.select_related("subject", "customer", "owner", "created_by").order_by("-created_at", "-id")
    return list(ordered[start : start + max(min(limit, MAX_LIMIT), 0)])
