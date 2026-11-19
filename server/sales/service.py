"""Create, edit and close leads. Audit rows carry ids only (never titles, values or reasons); the customer timeline
rows carry no title or value either, because every member of the file reads them, not only sales holders."""
from uuid import UUID

from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja.errors import HttpError

from accounts.models import User, audit
from accounts.notify import notify
from crm import membership, timeline
from crm.models import Customer
from workspace import registry
from workspace.changes import log, log_all
from workspace.events import emit
from workspace.models import Subject
from workspace.textbox import open_text, seal_text

from . import rules
from .models import Lead
from .schemas import LeadIn, LeadPatch, LoseIn

MODULE = "sales"
SECRET = ("description", "lost_reason")
PLAIN_PATCH = ("title", "value", "probability")


def gate(user: User) -> None:
    """404 when the module is off or the caller does not hold `sales.manage`."""
    registry.require_module(MODULE)
    if not rules.holds(user):
        raise HttpError(404, "Not found")


def visible(user: User, lead_id: UUID, *, lock: bool = False) -> Lead:
    gate(user)
    rows = rules.visible_leads(user).select_related("subject", "customer", "owner", "created_by")
    if lock:
        rows = rows.select_for_update(of=("self",))
    return get_object_or_404(rows, pk=lead_id)


def allowed(user: User, lead_id: UUID, action: str = "edit", *, lock: bool = True) -> Lead:
    lead = visible(user, lead_id, lock=lock)
    if not rules.can(user, lead, action):
        raise HttpError(403, "Permission denied")
    return lead


def member_customer(user: User, customer_id: UUID) -> Customer:
    registry.require_module("crm")
    customer = Customer.objects.select_related("subject").filter(pk=customer_id).first()
    if customer is None or membership.role_in(user, customer.pk) is None:
        raise HttpError(422, "Unknown customer")
    return customer


def check_owner(owner_id: int, customer: Customer | None) -> User:
    """The follow-up person must hold `sales.manage` and, for a customer-linked lead, be a member of that file."""
    owner = User.objects.filter(pk=owner_id, is_active=True).first()
    if owner is None or not rules.holds(owner):
        raise HttpError(422, "The owner must be an active user with sales.manage")
    if customer is not None and membership.role_in(owner, customer.pk) is None:
        raise HttpError(422, "The owner must be a member of the customer file")
    return owner


def _timeline(lead: Lead, user: User, what: str) -> None:
    if lead.customer_id:
        timeline.record(lead.customer, "lead", f"Lead {what}", by=user, ref_subject=lead.subject)


def _notify_owner(kind: str, lead: Lead, actor: User) -> None:
    if lead.owner_id != actor.id:
        emit(MODULE, kind, lead.subject, lead.title, actor, {lead.owner_id}, object_id=str(lead.id))


def _assigned(lead: Lead, actor: User, kind: str = "lead.assigned") -> None:
    _notify_owner(kind, lead, actor)
    if lead.owner_id != actor.id:
        notify([lead.owner], "lead.assigned", lead.title, module=MODULE, subject_id=str(lead.subject_id),
               object_id=str(lead.id))


@transaction.atomic
def create_lead(user: User, data: LeadIn) -> Lead:
    customer = member_customer(user, data.customer_id) if data.customer_id else None
    owner = check_owner(data.owner_id, customer) if data.owner_id else user
    subject = Subject.objects.create(module=MODULE, kind="lead")
    lead = Lead.objects.create(
        subject=subject, customer=customer, title=data.title.strip(), value=data.value,
        probability=data.probability, owner=owner, created_by=user,
        description=seal_text(data.description.text if data.description else ""))
    log(subject, user, "status", None, lead.status)
    audit(user, "lead_created", str(lead.id))
    _timeline(lead, user, "created")
    _assigned(lead, user, "lead.created")
    return lead


def _plain_changes(lead: Lead, data: LeadPatch, fields: set[str]) -> dict:
    changes = {}
    for name in PLAIN_PATCH:
        if name not in fields:
            continue
        value = getattr(data, name)
        if value is None:
            raise HttpError(422, f"{name} cannot be empty")
        value = value.strip() if isinstance(value, str) else value
        if getattr(lead, name) != value:
            changes[name] = (getattr(lead, name), value)
            setattr(lead, name, value)
    return changes


def _link_changes(user: User, lead: Lead, data: LeadPatch, fields: set[str]) -> dict:
    changes = {}
    if "description" in fields:
        text = data.description.text if data.description else ""
        if text != open_text(lead.description):
            lead.description = seal_text(text)
            changes["description"] = (None, None)
    customer = lead.customer
    if "customer_id" in fields and data.customer_id != lead.customer_id:
        customer = member_customer(user, data.customer_id) if data.customer_id else None
        changes["customer"] = (str(lead.customer_id) if lead.customer_id else None,
                               str(customer.pk) if customer else None)
        lead.customer = customer
    if "owner_id" in fields:
        if data.owner_id is None:
            raise HttpError(422, "owner_id cannot be empty")
    if "owner_id" in fields or "customer_id" in changes:
        owner = check_owner(data.owner_id if "owner_id" in fields else lead.owner_id, customer)
        if owner.id != lead.owner_id:
            changes["owner"] = (lead.owner_id, owner.id)
            lead.owner = owner
    return changes


@transaction.atomic
def update_lead(user: User, lead_id: UUID, data: LeadPatch) -> Lead:
    lead = allowed(user, lead_id)
    if lead.status != Lead.OPEN:
        raise HttpError(409, "Reopen the lead before editing it")
    fields = data.model_fields_set
    changes = _plain_changes(lead, data, fields) | _link_changes(user, lead, data, fields)
    if changes:
        lead.updated_at = timezone.now()
        lead.save()
        log_all(lead.subject, user, changes, SECRET)
        audit(user, "lead_updated", str(lead.id), fields=sorted(changes))
        if "owner" in changes:
            _assigned(lead, user)
    return lead


def _close(user: User, lead_id: UUID, status: str, reason: str = "") -> Lead:
    lead = allowed(user, lead_id)
    if lead.status != Lead.OPEN:
        raise HttpError(409, "The lead is already closed")
    now = timezone.now()
    lead.status, lead.closed_at, lead.updated_at = status, now, now
    changes = {"status": (Lead.OPEN, status)}
    if reason:
        lead.lost_reason = seal_text(reason)
        changes["lost_reason"] = (None, None)
    lead.save()
    log_all(lead.subject, user, changes, SECRET)
    audit(user, f"lead_{status}", str(lead.id))
    _timeline(lead, user, status)
    _notify_owner(f"lead.{status}", lead, user)
    return lead


@transaction.atomic
def win_lead(user: User, lead_id: UUID) -> Lead:
    return _close(user, lead_id, Lead.WON)


@transaction.atomic
def lose_lead(user: User, lead_id: UUID, data: LoseIn) -> Lead:
    reason = data.reason.strip()
    if not reason:
        raise HttpError(422, "A reason is required")
    return _close(user, lead_id, Lead.LOST, reason)


@transaction.atomic
def reopen_lead(user: User, lead_id: UUID) -> Lead:
    lead = allowed(user, lead_id)
    if lead.status == Lead.OPEN:
        raise HttpError(409, "The lead is already open")
    old = lead.status
    lead.status, lead.closed_at, lead.updated_at = Lead.OPEN, None, timezone.now()
    changes = {"status": (old, Lead.OPEN)}
    if old == Lead.LOST:
        lead.lost_reason = {}
        changes["lost_reason"] = (None, None)
    lead.save()
    log_all(lead.subject, user, changes, SECRET)
    audit(user, "lead_reopened", str(lead.id))
    _timeline(lead, user, "reopened")
    _notify_owner("lead.reopened", lead, user)
    return lead
