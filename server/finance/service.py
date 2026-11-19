"""Create, edit, confirm and void finance documents. Audit rows carry ids only (never amounts, reasons or text);
the customer timeline never shows amounts either (every member of the file reads it, not only finance holders)."""
from datetime import date
from uuid import UUID

from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja.errors import HttpError

from accounts.models import User, audit
from crm import membership, timeline
from crm.models import Customer
from workspace import registry
from workspace.changes import log, log_all
from workspace.events import emit
from workspace.models import Subject
from workspace.textbox import open_text, seal_text

from . import reports, rules
from .models import FinanceDoc
from .schemas import ConfirmIn, DocIn, DocPatch, VoidIn

MODULE = "finance"
SECRET = ("description", "void_reason")
CREATABLE_KINDS = (FinanceDoc.CASH, FinanceDoc.CHEQUE, FinanceDoc.PROBABLE)
PLAIN_PATCH = ("kind", "direction", "amount", "date", "due_date")


def gate(user: User) -> None:
    """404 when the module is off or the caller does not hold `finance.manage` (existence is not revealed)."""
    registry.require_module(MODULE)
    if not rules.holds(user):
        raise HttpError(404, "Not found")


def visible(user: User, doc_id: UUID, *, lock: bool = False) -> FinanceDoc:
    gate(user)
    rows = rules.visible_docs(user).select_related("subject", "customer", "created_by", "voided_by")
    if lock:
        rows = rows.select_for_update(of=("self",))
    return get_object_or_404(rows, pk=doc_id)


def member_customer(user: User, customer_id: UUID) -> Customer:
    """The customer file to link: the caller must be a member (any role)."""
    registry.require_module("crm")
    customer = Customer.objects.select_related("subject").filter(pk=customer_id).first()
    if customer is None or membership.role_in(user, customer.pk) is None:
        raise HttpError(422, "Unknown customer")
    return customer


def check_shape(kind: str, direction: str, due_date: date | None, status: str) -> None:
    if kind not in CREATABLE_KINDS:
        raise HttpError(422, "kind must be cash, cheque or probable (use /void to cancel a document)")
    if direction not in (FinanceDoc.RECEIPT, FinanceDoc.PAYMENT):
        raise HttpError(422, "direction must be receipt or payment")
    if kind in FinanceDoc.DUE_KINDS and due_date is None:
        raise HttpError(422, "due_date is required for cheques and probable documents")
    if kind == FinanceDoc.CASH and status == FinanceDoc.PENDING:
        raise HttpError(422, "A cash document cannot be pending")


def _timeline(doc: FinanceDoc, user: User, what: str) -> None:
    if doc.customer_id:
        text = f"Finance document {what}: {doc.direction}, {doc.kind}"
        timeline.record(doc.customer, "finance", text, by=user, ref_subject=doc.subject)


def _event(kind: str, doc: FinanceDoc, user: User) -> None:
    emit(MODULE, kind, doc.subject, "", user, rules.audience(doc), object_id=str(doc.id))


@transaction.atomic
def create_doc(user: User, data: DocIn) -> FinanceDoc:
    status = data.status or (FinanceDoc.CONFIRMED if data.kind == FinanceDoc.CASH else FinanceDoc.PENDING)
    if status not in (FinanceDoc.CONFIRMED, FinanceDoc.PENDING):
        raise HttpError(422, "status must be confirmed or pending")
    check_shape(data.kind, data.direction, data.due_date, status)
    customer = member_customer(user, data.customer_id) if data.customer_id else None
    subject = Subject.objects.create(module=MODULE, kind="doc")
    doc = FinanceDoc.objects.create(
        subject=subject, customer=customer, kind=data.kind, direction=data.direction, amount=data.amount,
        date=data.date, due_date=data.due_date, status=status, created_by=user,
        description=seal_text(data.description.text if data.description else ""))
    log(subject, user, "status", None, status)
    audit(user, "finance_doc_created", str(doc.id))
    _timeline(doc, user, "recorded")
    _event("finance.created", doc, user)
    return doc


def _apply_plain(doc: FinanceDoc, data: DocPatch, fields: set[str]) -> dict:
    changes = {}
    for name in PLAIN_PATCH:
        if name not in fields:
            continue
        value = getattr(data, name)
        if value is None and name != "due_date":
            raise HttpError(422, f"{name} cannot be empty")
        if getattr(doc, name) != value:
            changes[name] = (getattr(doc, name), value)
            setattr(doc, name, value)
    return changes


def _apply_text_and_customer(user: User, doc: FinanceDoc, data: DocPatch, fields: set[str]) -> dict:
    changes = {}
    if "description" in fields:
        text = data.description.text if data.description else ""
        if text != open_text(doc.description):
            doc.description = seal_text(text)
            changes["description"] = (None, None)
    if "customer_id" in fields and data.customer_id != doc.customer_id:
        customer = member_customer(user, data.customer_id) if data.customer_id else None
        changes["customer"] = (str(doc.customer_id) if doc.customer_id else None,
                               str(customer.pk) if customer else None)
        doc.customer = customer
    return changes


@transaction.atomic
def update_doc(user: User, doc_id: UUID, data: DocPatch) -> FinanceDoc:
    doc = visible(user, doc_id, lock=True)
    if doc.status == FinanceDoc.VOIDED:
        raise HttpError(409, "A voided document cannot be edited")
    fields = data.model_fields_set
    changes = _apply_plain(doc, data, fields) | _apply_text_and_customer(user, doc, data, fields)
    check_shape(doc.kind, doc.direction, doc.due_date, doc.status)
    if changes:
        doc.updated_at = timezone.now()
        doc.save()
        log_all(doc.subject, user, changes, SECRET)
        audit(user, "finance_doc_updated", str(doc.id), fields=sorted(changes))
    return doc


@transaction.atomic
def confirm_doc(user: User, doc_id: UUID, data: ConfirmIn) -> FinanceDoc:
    doc = visible(user, doc_id, lock=True)
    if doc.status != FinanceDoc.PENDING:
        raise HttpError(409, "Only pending documents can be confirmed")
    actual = data.date or reports.today()
    changes = {"status": (doc.status, FinanceDoc.CONFIRMED), "date": (doc.date, actual)}
    doc.status, doc.date, doc.updated_at = FinanceDoc.CONFIRMED, actual, timezone.now()
    doc.save()
    log_all(doc.subject, user, changes)
    audit(user, "finance_doc_confirmed", str(doc.id))
    _timeline(doc, user, "confirmed")
    return doc


@transaction.atomic
def void_doc(user: User, doc_id: UUID, data: VoidIn) -> FinanceDoc:
    doc = visible(user, doc_id, lock=True)
    if doc.status == FinanceDoc.VOIDED:
        raise HttpError(409, "The document is already void")
    reason = data.reason.strip()
    if not reason:
        raise HttpError(422, "A reason is required")
    old = doc.status
    doc.status, doc.voided_by, doc.voided_at = FinanceDoc.VOIDED, user, timezone.now()
    doc.void_reason, doc.updated_at = seal_text(reason), doc.voided_at
    doc.save()
    log_all(doc.subject, user, {"status": (old, FinanceDoc.VOIDED), "void_reason": (None, None)}, SECRET)
    audit(user, "finance_doc_voided", str(doc.id))
    _timeline(doc, user, "voided")
    _event("finance.voided", doc, user)
    return doc
