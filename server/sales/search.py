"""Unified search for `sales.manage` holders: lead title, customer name, value."""
from django.db.models import Q

from accounts.models import User
from workspace.search import amount_of, hit

from .rules import visible_leads


def search(user: User, q: str, limit: int) -> list[dict]:
    match = Q(title__icontains=q) | Q(customer__name__icontains=q)
    amount = amount_of(q)
    if amount is not None:
        match |= Q(value=amount)
    rows = visible_leads(user).filter(match).select_related("customer").order_by("-updated_at", "id")[:limit]
    return [hit("sales", "lead", x.id, x.subject_id, x.title, x.customer.name if x.customer_id else x.status,
                x.updated_at) for x in rows]
