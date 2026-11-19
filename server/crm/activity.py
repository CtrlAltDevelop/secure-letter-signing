"""Manual timeline notes, call reports, and turning a call into a task."""
from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja.errors import HttpError

from accounts.models import User, audit
from tasks import service as task_service
from tasks.models import Task
from tasks.schemas import DescriptionIn, TaskIn
from workspace import registry
from workspace.textbox import open_text, seal_text

from . import timeline
from .models import CallReport, Customer, CustomerEvent
from .schemas import CallIn, CallToTaskIn, EventIn

MAX_PAGE = 200
CALL_LABEL = {CallReport.IN: "Incoming call", CallReport.OUT: "Outgoing call"}


def page(rows, limit: int, offset: int) -> list:
    start = max(offset, 0)
    return list(rows[start : start + max(min(limit, MAX_PAGE), 0)])


def list_events(customer: Customer, kind: str, limit: int, offset: int) -> list[CustomerEvent]:
    rows = CustomerEvent.objects.filter(customer=customer).select_related("by").order_by("-at", "-id")
    if kind:
        rows = rows.filter(kind=kind)
    return page(rows, limit, offset)


def add_event(user: User, customer: Customer, data: EventIn) -> CustomerEvent:
    event = timeline.record(customer, data.kind, data.summary, by=user)
    if data.at is not None:
        CustomerEvent.objects.filter(pk=event.pk).update(at=data.at)
        event.refresh_from_db()
    return event


def list_calls(customer: Customer, limit: int, offset: int) -> list[CallReport]:
    return page(CallReport.objects.filter(customer=customer).select_related("by").order_by("-at", "-id"),
                limit, offset)


@transaction.atomic
def add_call(user: User, customer: Customer, data: CallIn) -> CallReport:
    call = CallReport.objects.create(
        customer=customer, direction=data.direction, contact_name=data.contact_name.strip(),
        summary=seal_text(data.summary.strip()), at=data.at or timezone.now(), duration_s=data.duration_s, by=user)
    who = f" ({call.contact_name})" if call.contact_name else ""
    timeline.record(customer, "call", f"{CALL_LABEL[call.direction]}{who}: {data.summary.strip()}", by=user)
    audit(user, "customer_call_logged", str(customer.id), call=call.id)
    return call


@transaction.atomic
def call_to_task(user: User, customer: Customer, call_id: int, data: CallToTaskIn) -> Task:
    """A normal task linked to the customer (needs `task.create`); `create_task` writes the timeline row."""
    registry.require_module("tasks")
    if not user.has_grant("task.create"):
        raise HttpError(403, "Permission denied")
    call = get_object_or_404(CallReport, pk=call_id, customer=customer)
    title = (data.title or f"Follow up: {call.contact_name or customer.name}").strip()[:200]
    body = TaskIn(title=title, owner_ids=data.owner_ids, due_at=data.due_at, customer_id=customer.id,
                  description=DescriptionIn(text=open_text(call.summary)))
    task = task_service.create_task(user, body)
    audit(user, "customer_call_to_task", str(customer.id), call=call.id, task=str(task.id))
    return task
