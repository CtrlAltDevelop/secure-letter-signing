"""Who may do what with a customer file (registry `can`). Only members act; the company manager gets nothing."""
from accounts.models import User

from . import membership
from .models import Customer

ANY_MEMBER = {"see", "comment"}
WORKERS = {"label", "link", "event", "call"}
MANAGER_ONLY = {"edit", "moderate", "members"}


def can(user: User, customer: Customer, action: str) -> bool:
    role = membership.role_in(user, customer.pk)
    if role is None:
        return False
    if action in ANY_MEMBER:
        return True
    if action in WORKERS:
        return role in membership.CAN_WORK
    return action in MANAGER_ONLY and role == membership.MANAGER


def audience(customer: Customer) -> set[int]:
    return membership.member_ids(customer.pk)
