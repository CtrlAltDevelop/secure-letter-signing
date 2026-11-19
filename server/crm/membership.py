"""Who is on a customer file. Imported by tasks, meetings and letters, so it must not import those apps."""
from collections.abc import Iterable

from accounts.models import User

from .models import Customer, CustomerMember

MANAGER, MEMBER, VIEWER = CustomerMember.MANAGER, CustomerMember.MEMBER, CustomerMember.VIEWER
CAN_WORK = {MANAGER, MEMBER}  # may link tasks/meetings/letters and add calls and notes


def role_in(user: User, customer_id) -> str | None:
    """The user's active role on the file, or None (also for the company manager: no automatic access)."""
    return (CustomerMember.objects.filter(customer_id=customer_id, user=user, active=True)
            .values_list("role", flat=True).first())


def member_ids(customer_id) -> set[int]:
    return set(CustomerMember.objects.filter(customer_id=customer_id, active=True, user__is_active=True)
               .values_list("user_id", flat=True))


def visible_customers(user: User):
    mine = CustomerMember.objects.filter(user=user, active=True).values("customer_id")
    return Customer.objects.filter(pk__in=mine)


def visible_ids(user: User, ids: Iterable) -> set:
    """The subset of `ids` the user is an active member of."""
    return set(CustomerMember.objects.filter(user=user, active=True, customer_id__in=list(ids))
               .values_list("customer_id", flat=True))


def visible_names(user: User, ids: Iterable) -> dict:
    """{customer_id: name} for the files among `ids` the user is a member of (others stay hidden)."""
    wanted = [i for i in set(ids) if i]
    if not wanted:
        return {}
    return dict(visible_customers(user).filter(pk__in=wanted).values_list("pk", "name"))
