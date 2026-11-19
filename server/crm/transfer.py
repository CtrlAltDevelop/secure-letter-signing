"""Work transfer for customer files: the source's active memberships (ownership included) move to the target."""
from django.utils import timezone

from accounts.models import User
from workspace.changes import log

from . import membership, notices
from .models import CustomerMember

RANK = {membership.VIEWER: 0, membership.MEMBER: 1, membership.MANAGER: 2}


def _grant(row: CustomerMember, target: CustomerMember | None, owner: bool) -> str | None:
    """The role the target must end up with, or None when it already has that or a higher role (nothing to do)."""
    wanted = membership.MANAGER if owner else row.role
    if target is not None and target.active and RANK[target.role] >= RANK[wanted]:
        return None
    return wanted


def _apply(customer, to_user: User, role: str, actor: User, target: CustomerMember | None) -> None:
    if target is None:
        CustomerMember.objects.create(customer=customer, user=to_user, role=role, added_by=actor)
        return
    if not target.active:
        target.added_by, target.at = actor, timezone.now()
    target.active, target.role = True, role
    target.save()


def transfer(from_user: User, to_user: User, actor: User) -> int:
    """Hand over every active membership; the role is kept (the owner becomes the target's manager role and owner).
    A target who is already a member with a higher role keeps it and that file does not count as moved."""
    rows = CustomerMember.objects.select_for_update().filter(user=from_user, active=True).select_related("customer")
    moved = 0
    for row in rows:
        customer = row.customer
        target = CustomerMember.objects.filter(customer=customer, user=to_user).first()
        owner = customer.owner_id == from_user.id
        role = _grant(row, target, owner)
        if role is not None:
            _apply(customer, to_user, role, actor, target)
        row.active = False
        row.save(update_fields=["active"])
        if owner:
            customer.owner = to_user
        if owner or role is not None:
            customer.updated_at = timezone.now()
            customer.save()
            log(customer.subject, actor, "transfer", {"from": from_user.id}, {"to": to_user.id, "owner": owner})
            notices.emit_customer("customer.updated", customer, actor, fields=["members"])
            moved += 1
    return moved
