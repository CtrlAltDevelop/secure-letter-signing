"""Work transfer for sales: open leads owned or created by the source move to the target (who must hold
`sales.manage`; a lead linked to a customer file also needs the target to be a member of that file, else it is skipped)."""
from django.db.models import Q
from django.utils import timezone

from accounts.models import User
from crm import membership
from workspace.changes import log

from . import rules
from .models import Lead


def transfer(from_user: User, to_user: User, actor: User) -> int:
    if not rules.holds(to_user):
        return 0
    rows = (Lead.objects.select_for_update().filter(status=Lead.OPEN).filter(Q(owner=from_user) | Q(created_by=from_user))
            .select_related("customer", "subject"))
    moved = 0
    for lead in rows:
        if lead.customer_id and membership.role_in(to_user, lead.customer_id) is None:
            continue
        changes = {}
        if lead.owner_id == from_user.id:
            lead.owner, changes["owner"] = to_user, from_user.id
        if lead.created_by_id == from_user.id:
            lead.created_by, changes["created_by"] = to_user, from_user.id
        lead.updated_at = timezone.now()
        lead.save()
        for field, old in changes.items():
            log(lead.subject, actor, field, old, to_user.id)
        moved += 1
    return moved
