"""Who sees finance documents: `finance.manage` holders only (everyone else gets 404), and a document linked to a
customer additionally needs membership (any role) of that customer file. The company manager gets nothing extra."""
from django.db.models import Q, QuerySet

from accounts.models import User
from crm import membership

from .models import FinanceDoc

PERMISSION = "finance.manage"
HOLDER_ACTIONS = {"see", "label", "comment", "edit"}


def holds(user: User) -> bool:
    return user.has_grant(PERMISSION)


def can(user: User, doc: FinanceDoc, action: str) -> bool:
    if not holds(user):
        return False
    if doc.customer_id and membership.role_in(user, doc.customer_id) is None:
        return False
    if action == "moderate":  # delete other people's comments and files: the creator only
        return doc.created_by_id == user.id
    return action in HOLDER_ACTIONS


def audience(doc: FinanceDoc) -> set[int]:
    return {doc.created_by_id}


def visible_docs(user: User) -> QuerySet[FinanceDoc]:
    if not holds(user):
        return FinanceDoc.objects.none()
    mine = membership.visible_customers(user).values("pk")
    return FinanceDoc.objects.filter(Q(customer__isnull=True) | Q(customer_id__in=mine))
