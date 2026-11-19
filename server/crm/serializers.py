"""Customer -> CustomerBrief / CustomerOut, events and calls."""
from collections.abc import Sequence

from accounts.models import User
from workspace.access import my_label_ids
from workspace.models import SeenBy
from workspace.schemas import user_ref
from workspace.textbox import open_text

from . import rules
from .models import CallReport, Customer, CustomerEvent, CustomerMember
from .schemas import CallOut, CanOut, CustomerBrief, CustomerOut, DescriptionOut, EventOut, MemberOut

CAN_ACTIONS = ("see", "comment", "label", "link", "event", "call", "edit", "members")


def briefs(user: User, customers: Sequence[Customer]) -> list[CustomerBrief]:
    roles = dict(CustomerMember.objects.filter(user=user, active=True, customer__in=customers)
                 .values_list("customer_id", "role"))
    seen = dict(SeenBy.objects.filter(user=user, subject_id__in=[c.subject_id for c in customers])
                .values_list("subject_id", "last_at"))
    out = []
    for c in customers:
        last = seen.get(c.subject_id)
        out.append(CustomerBrief(
            id=c.id, subject_id=c.subject_id, kind=c.kind, name=c.name, legal_name=c.legal_name,
            national_id=c.national_id, phone=c.phone, mobile=c.mobile, email=c.email, status=c.status,
            owner_id=c.owner_id, my_role=roles.get(c.id, ""), label_ids=my_label_ids(user, c.subject),
            unseen=last is None or c.updated_at > last, updated_at=c.updated_at))
    return out


def customer_out(user: User, customer: Customer) -> CustomerOut:
    brief = briefs(user, [customer])[0]
    rows = (CustomerMember.objects.filter(customer=customer, active=True).select_related("user")
            .order_by("id"))
    return CustomerOut(
        **brief.model_dump(), registration_no=customer.registration_no,
        address=DescriptionOut(text=open_text(customer.address)), notes=DescriptionOut(text=open_text(customer.notes)),
        owner=user_ref(customer.owner), members=[MemberOut(user=user_ref(m.user), role=m.role) for m in rows],
        can=CanOut(**{a: rules.can(user, customer, a) for a in CAN_ACTIONS}), created_at=customer.created_at)


def event_out(e: CustomerEvent) -> EventOut:
    return EventOut(id=e.id, kind=e.kind, summary=open_text(e.summary), at=e.at,
                    by=user_ref(e.by) if e.by else None, ref_subject_id=e.ref_subject_id)


def call_out(c: CallReport) -> CallOut:
    return CallOut(id=c.id, direction=c.direction, contact_name=c.contact_name, summary=open_text(c.summary),
                   at=c.at, duration_s=c.duration_s, by=user_ref(c.by))

