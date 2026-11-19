"""Lead -> LeadOut."""
from collections.abc import Sequence

from accounts.models import User
from workspace.access import my_label_ids
from workspace.schemas import TextBody, user_ref
from workspace.textbox import open_text

from . import rules
from .models import Lead
from .schemas import LeadOut


def weighted(value: int, probability: int) -> int:
    return value * probability // 100


def lead_out(user: User, lead: Lead) -> LeadOut:
    return LeadOut(
        id=lead.id, subject_id=lead.subject_id, customer_id=lead.customer_id,
        customer_name=lead.customer.name if lead.customer_id else None, title=lead.title, value=lead.value,
        probability=lead.probability, weighted_value=weighted(lead.value, lead.probability), status=lead.status,
        owner=user_ref(lead.owner), description=TextBody(text=open_text(lead.description)),
        closed_at=lead.closed_at,
        lost_reason=TextBody(text=open_text(lead.lost_reason)) if lead.status == Lead.LOST else None,
        created_by=user_ref(lead.created_by), created_at=lead.created_at, updated_at=lead.updated_at,
        label_ids=my_label_ids(user, lead.subject), can_edit=rules.can(user, lead, "edit"))


def leads_out(user: User, leads: Sequence[Lead]) -> list[LeadOut]:
    return [lead_out(user, lead) for lead in leads]
