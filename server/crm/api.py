"""Customers API (mounted at /api/customers). Rules in rules.py, edits in service/activity, imports in imports."""
from uuid import UUID

from django.db.models import Q
from django.shortcuts import get_object_or_404
from ninja import File as UploadField
from ninja import Form, Router
from ninja.errors import HttpError
from ninja.files import UploadedFile

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, user_of
from accounts.models import User
from letters.schemas import LetterBrief
from meetings.schemas import MeetingBrief
from tasks.schemas import TaskBrief
from tasks.serializers import briefs as task_briefs
from workspace.access import visible_labels
from workspace.models import ChangeHistory, SubjectLabel
from workspace.schemas import HistoryOut, user_ref
from workspace.seen import mark_seen

from . import activity, imports, links, membership, rules, service
from .models import Customer
from .schemas import (CallIn, CallOut, CallToTaskIn, CustomerBrief, CustomerIn, CustomerOut, CustomerPatch, EventIn,
                      EventOut, ImportOut, MemberIn)
from .serializers import briefs, call_out, customer_out, event_out

router = Router(tags=["crm"], auth=BearerAuth())
ERRORS = {403: Detail, 404: Detail, 409: Detail, 422: Detail}
STATUS_VALUES = {Customer.ACTIVE, Customer.INACTIVE, Customer.ARCHIVED}
MAX_LIMIT = 200
SEARCH_FIELDS = ("name", "legal_name", "phone", "mobile", "email", "national_id")


def _visible(user: User, customer_id: UUID) -> Customer:
    service.gate()
    customer = get_object_or_404(Customer.objects.select_related("subject", "owner"), pk=customer_id)
    if not rules.can(user, customer, "see"):
        raise HttpError(404, "Not found")
    return customer


def _allowed(user: User, customer_id: UUID, action: str) -> Customer:
    customer = _visible(user, customer_id)
    if not rules.can(user, customer, action):
        raise HttpError(403, "Permission denied")
    return customer


def _out(user: User, customer: Customer) -> CustomerOut:
    return customer_out(user, Customer.objects.select_related("subject", "owner").get(pk=customer.pk))


@router.post("", response={201: CustomerOut, **ERRORS})
def create(request, data: CustomerIn):
    service.gate()
    user = user_of(request)
    if not user.has_grant("customer.create"):
        raise HttpError(403, "Permission denied")
    return 201, _out(user, service.create_customer(user, data))


@router.get("", response=list[CustomerBrief])
def list_customers(request, q: str = "", status: str = "", kind: str = "", label: int | None = None,
                   mine: bool = False, limit: int = 50, offset: int = 0):
    service.gate()
    user = user_of(request)
    rows = membership.visible_customers(user).select_related("subject")
    wanted = {s for s in status.split(",") if s}
    if wanted:
        rows = rows.filter(status__in=wanted & STATUS_VALUES)
    if kind:
        rows = rows.filter(kind=kind)
    if q.strip():
        rows = rows.filter(_search(q.strip()))
    if mine:
        rows = rows.filter(owner=user)
    if label is not None:
        ok = visible_labels(user).filter(pk=label, active=True).exists()
        subjects = SubjectLabel.objects.filter(label_id=label, active=True).values("subject_id") if ok else []
        rows = rows.filter(subject_id__in=subjects)
    start = max(offset, 0)
    page = rows.order_by("name", "id")[start : start + max(min(limit, MAX_LIMIT), 0)]
    return briefs(user, list(page))


def _search(text: str) -> Q:
    query = Q()
    for name in SEARCH_FIELDS:
        query |= Q(**{f"{name}__icontains": text})
    return query


@router.post("/import", response={200: ImportOut, 413: Detail, **ERRORS})
def import_customers(request, format: Form[str], file: UploadedFile = UploadField(...)):
    service.gate()
    user = user_of(request)
    if not user.has_grant("customer.import"):
        raise HttpError(403, "Permission denied")
    if format not in ("csv", "xlsx"):
        raise HttpError(422, "format must be csv or xlsx")
    return imports.import_rows(user, imports.read_rows(file.read(), format))


@router.get("/{uuid:customer_id}", response={200: CustomerOut, 404: Detail})
def get_customer(request, customer_id: UUID):
    user = user_of(request)
    customer = _visible(user, customer_id)
    mark_seen(user, customer.subject)
    return _out(user, customer)


@router.patch("/{uuid:customer_id}", response={200: CustomerOut, **ERRORS})
def patch(request, customer_id: UUID, data: CustomerPatch):
    service.gate()
    user = user_of(request)
    return _out(user, service.update_customer(user, customer_id, data))


@router.put("/{uuid:customer_id}/members", response={200: CustomerOut, **ERRORS})
def put_members(request, customer_id: UUID, data: list[MemberIn]):
    service.gate()
    user = user_of(request)
    return _out(user, service.set_members(user, customer_id, data))


@router.get("/{uuid:customer_id}/history", response={200: list[HistoryOut], 404: Detail})
def history(request, customer_id: UUID, limit: int = 100, offset: int = 0):
    customer = _visible(user_of(request), customer_id)
    rows = ChangeHistory.objects.filter(subject=customer.subject).select_related("actor").order_by("-at", "-id")
    return [HistoryOut(id=h.id, actor=user_ref(h.actor) if h.actor else None, field=h.field, old=h.old,
                       new=h.new, at=h.at) for h in activity.page(rows, limit, offset)]


@router.get("/{uuid:customer_id}/events", response={200: list[EventOut], 404: Detail})
def list_events(request, customer_id: UUID, kind: str = "", limit: int = 50, offset: int = 0):
    customer = _visible(user_of(request), customer_id)
    return [event_out(e) for e in activity.list_events(customer, kind, limit, offset)]


@router.post("/{uuid:customer_id}/events", response={201: EventOut, **ERRORS})
def add_event(request, customer_id: UUID, data: EventIn):
    user = user_of(request)
    return 201, event_out(activity.add_event(user, _allowed(user, customer_id, "event"), data))


@router.get("/{uuid:customer_id}/calls", response={200: list[CallOut], 404: Detail})
def list_calls(request, customer_id: UUID, limit: int = 50, offset: int = 0):
    customer = _visible(user_of(request), customer_id)
    return [call_out(c) for c in activity.list_calls(customer, limit, offset)]


@router.post("/{uuid:customer_id}/calls", response={201: CallOut, **ERRORS})
def add_call(request, customer_id: UUID, data: CallIn):
    user = user_of(request)
    return 201, call_out(activity.add_call(user, _allowed(user, customer_id, "call"), data))


@router.post("/{uuid:customer_id}/calls/{int:call_id}/to-task", response={201: TaskBrief, **ERRORS})
def call_to_task(request, customer_id: UUID, call_id: int, data: CallToTaskIn | None = None):
    user = user_of(request)
    customer = _allowed(user, customer_id, "call")
    task = activity.call_to_task(user, customer, call_id, data or CallToTaskIn())
    return 201, task_briefs(user, [task])[0]


@router.get("/{uuid:customer_id}/tasks", response={200: list[TaskBrief], 404: Detail})
def customer_tasks(request, customer_id: UUID, limit: int = 50, offset: int = 0):
    user = user_of(request)
    return links.tasks_of(user, _visible(user, customer_id), limit, offset)


@router.get("/{uuid:customer_id}/meetings", response={200: list[MeetingBrief], 404: Detail})
def customer_meetings(request, customer_id: UUID, limit: int = 50, offset: int = 0):
    user = user_of(request)
    return links.meetings_of(user, _visible(user, customer_id), limit, offset)


@router.get("/{uuid:customer_id}/letters", response={200: list[LetterBrief], 404: Detail})
def customer_letters(request, customer_id: UUID, limit: int = 50, offset: int = 0):
    user = user_of(request)
    return links.letters_of(user, _visible(user, customer_id), limit, offset)
