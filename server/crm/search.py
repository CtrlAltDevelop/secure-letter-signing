"""Unified search over customer files the caller is a member of: name, phone, email, national id."""
from django.db.models import Q

from accounts.models import User
from workspace.search import hit

from .membership import visible_customers

CONTACT_FIELDS = ("phone", "mobile", "email", "national_id")


def _snippet(customer, q: str) -> str:
    needle = q.casefold()
    return next((v for v in (getattr(customer, f) for f in CONTACT_FIELDS) if v and needle in v.casefold()), "")


def search(user: User, q: str, limit: int) -> list[dict]:
    match = Q(name__icontains=q) | Q(legal_name__icontains=q)
    for field in CONTACT_FIELDS:
        match |= Q(**{f"{field}__icontains": q})
    rows = visible_customers(user).filter(match).order_by("-updated_at", "id")[:limit]
    return [hit("crm", "customer", c.id, c.subject_id, c.name, _snippet(c, q), c.updated_at) for c in rows]
