"""Finance API: documents (/finance/docs), reports and the per-customer view. Every route is 404 unless the caller
holds `finance.manage` (and the module is on). Mounted at "" because of the /customers/{id}/finance route."""
from datetime import date
from uuid import UUID

from ninja import Query, Router
from ninja.errors import HttpError

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, user_of
from workspace.models import ChangeHistory
from workspace.schemas import HistoryOut, user_ref

from . import periods_api, queries, reports, rules, service
from .models import FinanceDoc
from .schemas import (ChartOut, ConfirmIn, CustomerFinanceOut, DocIn, DocOut, DocPatch, MonthlyOut, SummaryOut,
                      VoidIn)
from .serializers import doc_out, docs_out

router = Router(tags=["finance"], auth=BearerAuth())
ERRORS = {403: Detail, 404: Detail, 409: Detail, 422: Detail}


def _out(user, doc: FinanceDoc) -> DocOut:
    return doc_out(user, doc, reports.today())


@router.post("/finance/docs", response={201: DocOut, **ERRORS})
def create(request, data: DocIn):
    user = user_of(request)
    service.gate(user)
    doc = service.create_doc(user, data)
    return 201, _out(user, service.visible(user, doc.id))


@router.get("/finance/docs", response={200: list[DocOut], 404: Detail})
def list_docs(request, customer: UUID | None = None, kind: str = "", direction: str = "", status: str = "",
              label: int | None = None, from_: date | None = Query(None, alias="from"), to: date | None = None,
              q: str = "", limit: int = 50, offset: int = 0):
    user = user_of(request)
    service.gate(user)
    rows = queries.filtered(user, rules.visible_docs(user), customer=customer, kind=kind, direction=direction,
                            status=status, label=label, start=from_, end=to, q=q)
    return docs_out(user, queries.page(rows, limit, offset), reports.today())


@router.get("/finance/docs/{uuid:doc_id}", response={200: DocOut, 404: Detail})
def get_doc(request, doc_id: UUID):
    user = user_of(request)
    return _out(user, service.visible(user, doc_id))


@router.patch("/finance/docs/{uuid:doc_id}", response={200: DocOut, **ERRORS})
def patch_doc(request, doc_id: UUID, data: DocPatch):
    user = user_of(request)
    service.update_doc(user, doc_id, data)
    return _out(user, service.visible(user, doc_id))


@router.post("/finance/docs/{uuid:doc_id}/confirm", response={200: DocOut, **ERRORS})
def confirm(request, doc_id: UUID, data: ConfirmIn | None = None):
    user = user_of(request)
    service.confirm_doc(user, doc_id, data or ConfirmIn())
    return _out(user, service.visible(user, doc_id))


@router.post("/finance/docs/{uuid:doc_id}/void", response={200: DocOut, **ERRORS})
def void(request, doc_id: UUID, data: VoidIn):
    user = user_of(request)
    service.void_doc(user, doc_id, data)
    return _out(user, service.visible(user, doc_id))


@router.get("/finance/docs/{uuid:doc_id}/history", response={200: list[HistoryOut], 404: Detail})
def history(request, doc_id: UUID, limit: int = 100, offset: int = 0):
    doc = service.visible(user_of(request), doc_id)
    rows = ChangeHistory.objects.filter(subject=doc.subject).select_related("actor").order_by("-at", "-id")
    start = max(offset, 0)
    return [HistoryOut(id=h.id, actor=user_ref(h.actor) if h.actor else None, field=h.field, old=h.old, new=h.new,
                       at=h.at) for h in rows[start : start + max(min(limit, queries.MAX_LIMIT), 0)]]


@router.get("/finance/summary", response={200: SummaryOut, 404: Detail, 422: Detail})
def summary(request, from_: date | None = Query(None, alias="from"), to: date | None = None, group_by: str = "month",
            calendar: str = "gregorian", label: int | None = None):
    user = user_of(request)
    service.gate(user)
    return periods_api.summary(user, from_, to, group_by, calendar, label)


@router.get("/finance/monthly", response={200: MonthlyOut, 404: Detail, 422: Detail})
def monthly(request, year: int):
    user = user_of(request)
    service.gate(user)
    return periods_api.monthly(user, year)


@router.get("/finance/chart", response={200: ChartOut, 404: Detail, 422: Detail})
def chart(request, from_: date | None = Query(None, alias="from"), to: date | None = None):
    user = user_of(request)
    service.gate(user)
    return periods_api.chart(user, from_, to)


@router.get("/customers/{uuid:customer_id}/finance", response={200: CustomerFinanceOut, 404: Detail})
def customer_finance(request, customer_id: UUID, limit: int = 100, offset: int = 0):
    user = user_of(request)
    service.gate(user)
    if not _is_member(user, customer_id):
        raise HttpError(404, "Not found")
    rows = rules.visible_docs(user).filter(customer_id=customer_id)
    return CustomerFinanceOut(customer_id=customer_id, totals=reports.totals(rows),
                              documents=docs_out(user, queries.page(rows, limit, offset), reports.today()))


def _is_member(user, customer_id: UUID) -> bool:
    from crm import membership
    from workspace import registry

    registry.require_module("crm")
    return membership.role_in(user, customer_id) is not None
