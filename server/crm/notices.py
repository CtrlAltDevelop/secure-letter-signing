"""Live events and notifications of the crm module. Titles may travel in events; audit rows never carry them."""
from collections.abc import Iterable

from accounts.models import User
from accounts.notify import notify
from workspace.events import emit

from . import rules
from .models import Customer

MODULE = "crm"


def emit_customer(kind: str, customer: Customer, actor: User, **data) -> None:
    """Event to every active member except the actor."""
    recipients = rules.audience(customer) - {actor.id}
    emit(MODULE, kind, customer.subject, customer.name, actor, recipients, object_id=str(customer.id), **data)


def notify_added(user_ids: Iterable[int], customer: Customer, actor: User) -> None:
    users = list(User.objects.filter(pk__in=set(user_ids) - {actor.id}, is_active=True))
    if users:
        notify(users, "customer.member_added", customer.name, module=MODULE,
               subject_id=str(customer.subject_id), object_id=str(customer.id))
