"""Who sees leads: `sales.manage` holders only (others get 404). A holder sees a lead when they own or created it, or
when `SALES_SHARED_VISIBILITY` is on (default); a lead linked to a customer also needs membership (any role) of that
file. Only the owner or creator may change, label or close a lead; any holder who sees it may comment."""
from django.conf import settings
from django.db.models import Q, QuerySet

from accounts.models import User
from crm import membership

from .models import Lead

PERMISSION = "sales.manage"
VIEW_ACTIONS = {"see", "comment"}
WORK_ACTIONS = {"label", "edit", "moderate"}


def holds(user: User) -> bool:
    return user.has_grant(PERMISSION)


def shared() -> bool:
    return bool(getattr(settings, "SALES_SHARED_VISIBILITY", True))


def _mine(user: User, lead: Lead) -> bool:
    return user.id in (lead.owner_id, lead.created_by_id)


def can(user: User, lead: Lead, action: str) -> bool:
    if not holds(user):
        return False
    if not (shared() or _mine(user, lead)):
        return False
    if lead.customer_id and membership.role_in(user, lead.customer_id) is None:
        return False
    if action in VIEW_ACTIONS:
        return True
    return action in WORK_ACTIONS and _mine(user, lead)


def audience(lead: Lead) -> set[int]:
    return {lead.owner_id}


def visible_leads(user: User) -> QuerySet[Lead]:
    if not holds(user):
        return Lead.objects.none()
    mine = membership.visible_customers(user).values("pk")
    rows = Lead.objects.filter(Q(customer__isnull=True) | Q(customer_id__in=mine))
    return rows if shared() else rows.filter(Q(owner=user) | Q(created_by=user))
