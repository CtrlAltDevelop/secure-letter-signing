"""Sales API: leads (/sales/leads), summary and the per-customer view. Every route is 404 unless the caller holds
`sales.manage` (and the module is on). Mounted at "" because of the /customers/{id}/leads route."""
from uuid import UUID

from ninja import Router
from ninja.errors import HttpError

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, user_of
from crm import membership
from workspace import registry
from workspace.models import ChangeHistory
from workspace.schemas import HistoryOut, user_ref

from . import queries, rules, service, summary
from .models import Lead
from .schemas import LeadIn, LeadOut, LeadPatch, LoseIn, SummaryOut
from .serializers import lead_out, leads_out

router = Router(tags=["sales"], auth=BearerAuth())
ERRORS = {403: Detail, 404: Detail, 409: Detail, 422: Detail}


def _out(user, lead_id: UUID) -> LeadOut:
    return lead_out(user, service.visible(user, lead_id))


@router.post("/sales/leads", response={201: LeadOut, **ERRORS})
def create(request, data: LeadIn):
    user = user_of(request)
    service.gate(user)
    return 201, _out(user, service.create_lead(user, data).id)


@router.get("/sales/leads", response={200: list[LeadOut], 404: Detail})
def list_leads(request, owner: int | None = None, customer: UUID | None = None, status: str = "",
               label: int | None = None, min_prob: int | None = None, max_prob: int | None = None, q: str = "",
               probability_bucket: str = "", limit: int = 50, offset: int = 0):
    user = user_of(request)
    service.gate(user)
    rows = queries.filtered(user, rules.visible_leads(user), owner=owner, customer=customer, status=status,
                            label=label, min_prob=min_prob, max_prob=max_prob, q=q, bucket=probability_bucket)
    return leads_out(user, queries.page(rows, limit, offset))


@router.get("/sales/summary", response={200: SummaryOut, 404: Detail})
def get_summary(request):
    user = user_of(request)
    service.gate(user)
    return summary.summarize(rules.visible_leads(user))


@router.get("/sales/leads/{uuid:lead_id}", response={200: LeadOut, 404: Detail})
def get_lead(request, lead_id: UUID):
    user = user_of(request)
    return _out(user, lead_id)


@router.patch("/sales/leads/{uuid:lead_id}", response={200: LeadOut, **ERRORS})
def patch_lead(request, lead_id: UUID, data: LeadPatch):
    user = user_of(request)
    service.update_lead(user, lead_id, data)
    return _out(user, lead_id)


@router.post("/sales/leads/{uuid:lead_id}/win", response={200: LeadOut, **ERRORS})
def win(request, lead_id: UUID):
    user = user_of(request)
    service.win_lead(user, lead_id)
    return _out(user, lead_id)


@router.post("/sales/leads/{uuid:lead_id}/lose", response={200: LeadOut, **ERRORS})
def lose(request, lead_id: UUID, data: LoseIn):
    user = user_of(request)
    service.lose_lead(user, lead_id, data)
    return _out(user, lead_id)


@router.post("/sales/leads/{uuid:lead_id}/reopen", response={200: LeadOut, **ERRORS})
def reopen(request, lead_id: UUID):
    user = user_of(request)
    service.reopen_lead(user, lead_id)
    return _out(user, lead_id)


@router.get("/sales/leads/{uuid:lead_id}/history", response={200: list[HistoryOut], 404: Detail})
def history(request, lead_id: UUID, limit: int = 100, offset: int = 0):
    lead: Lead = service.visible(user_of(request), lead_id)
    rows = ChangeHistory.objects.filter(subject=lead.subject).select_related("actor").order_by("-at", "-id")
    start = max(offset, 0)
    return [HistoryOut(id=h.id, actor=user_ref(h.actor) if h.actor else None, field=h.field, old=h.old, new=h.new,
                       at=h.at) for h in rows[start : start + max(min(limit, queries.MAX_LIMIT), 0)]]


@router.get("/customers/{uuid:customer_id}/leads", response={200: list[LeadOut], 404: Detail})
def customer_leads(request, customer_id: UUID, limit: int = 100, offset: int = 0):
    user = user_of(request)
    service.gate(user)
    registry.require_module("crm")
    if membership.role_in(user, customer_id) is None:
        raise HttpError(404, "Not found")
    rows = rules.visible_leads(user).filter(customer_id=customer_id)
    return leads_out(user, queries.page(rows, limit, offset))
