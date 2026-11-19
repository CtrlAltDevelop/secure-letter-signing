"""Create and edit customer files, replace their members. Audit rows carry ids only, never names."""
from uuid import UUID

from django.conf import settings
from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja.errors import HttpError

from accounts.models import User, audit
from workspace import registry
from workspace.models import Subject
from workspace.seen import mark_seen
from workspace.textbox import open_text, seal_text

from . import history, membership, notices, rules
from .models import Customer, CustomerMember
from .schemas import CustomerIn, CustomerPatch, MemberIn

PLAIN_FIELDS = ("kind", "name", "legal_name", "national_id", "registration_no", "phone", "mobile", "email", "status")
TEXT_FIELDS = ("address", "notes")
LIMIT_MESSAGE = "Customer limit reached"


def gate() -> None:
    registry.require_module("crm")


def customer_limit() -> int:
    return int(getattr(settings, "CUSTOMER_LIMIT", 10_000))


def room_left() -> int:
    """How many more customers fit (active, inactive and archived all count)."""
    return max(customer_limit() - Customer.objects.count(), 0)


def lock_customer(user: User, customer_id: UUID, action: str = "see") -> Customer:
    """Customer row locked for update: 404 unless the user is a member, 403 unless `action` is allowed."""
    customer = get_object_or_404(Customer.objects.select_for_update().select_related("subject"), pk=customer_id)
    if not rules.can(user, customer, "see"):
        raise HttpError(404, "Not found")
    if not rules.can(user, customer, action):
        raise HttpError(403, "Permission denied")
    return customer


def linkable(user: User, customer_id: UUID) -> Customer:
    """The customer a task or meeting may be linked to: the caller must be a manager/member of the file."""
    registry.require_module("crm")
    customer = Customer.objects.select_related("subject").filter(pk=customer_id).first()
    if customer is None or not rules.can(user, customer, "see"):
        raise HttpError(422, "Unknown customer")
    if not rules.can(user, customer, "link"):
        raise HttpError(403, "Permission denied")
    if customer.status == Customer.ARCHIVED:
        raise HttpError(409, "The customer file is archived")
    return customer


def _clean(field: str, value: str | None) -> str:
    value = (value or "").strip()
    return value.lower() if field == "email" else value


def checked_members(owner_id: int, members: list[MemberIn]) -> dict[int, str]:
    """{user_id: role} with the owner forced to manager; 422 for duplicates or unknown/inactive users."""
    wanted: dict[int, str] = {}
    for m in members:
        if m.user_id in wanted:
            raise HttpError(422, "A user appears twice in the member list")
        wanted[m.user_id] = m.role
    if wanted.get(owner_id, membership.MANAGER) != membership.MANAGER:
        raise HttpError(422, "The owner cannot be demoted")
    wanted[owner_id] = membership.MANAGER
    if User.objects.filter(pk__in=wanted, is_active=True).count() != len(wanted):
        raise HttpError(422, "Unknown or inactive user")
    if User.objects.filter(pk__in=wanted, is_guest=True).exists():  # guests never get customer files
        raise HttpError(422, "Unknown or inactive user")
    return wanted


def new_customer(user: User, values: dict, address: str = "", notes: str = "") -> Customer:
    """Customer + subject + owner membership. No limit check, no events: callers add those."""
    subject = Subject.objects.create(module=notices.MODULE, kind="customer")
    customer = Customer.objects.create(subject=subject, owner=user, address=seal_text(address),
                                       notes=seal_text(notes), **values)
    CustomerMember.objects.create(customer=customer, user=user, role=membership.MANAGER, added_by=user)
    return customer


@transaction.atomic
def create_customer(user: User, data: CustomerIn) -> Customer:
    if room_left() <= 0:
        raise HttpError(409, LIMIT_MESSAGE)
    wanted = checked_members(user.id, data.members)
    values = {f: _clean(f, getattr(data, f)) for f in PLAIN_FIELDS}
    customer = new_customer(user, values, data.address.text if data.address else "",
                            data.notes.text if data.notes else "")
    extra = {uid: role for uid, role in wanted.items() if uid != user.id}
    CustomerMember.objects.bulk_create([CustomerMember(customer=customer, user_id=uid, role=role, added_by=user)
                                        for uid, role in extra.items()])
    history.log(customer.subject, user, "status", None, customer.status)
    audit(user, "customer_created", str(customer.id))
    mark_seen(user, customer.subject)
    notices.emit_customer("customer.created", customer, user)
    notices.notify_added(extra, customer, user)
    return customer


def _plain_changes(customer: Customer, data: CustomerPatch, fields: set[str]) -> dict:
    changes = {}
    for name in PLAIN_FIELDS:
        if name not in fields:
            continue
        value = _clean(name, getattr(data, name))
        if not value and name in ("kind", "name", "status"):
            raise HttpError(422, f"{name} cannot be empty")
        if getattr(customer, name) != value:
            changes[name] = (getattr(customer, name), value)
            setattr(customer, name, value)
    return changes


def _text_changes(customer: Customer, data: CustomerPatch, fields: set[str]) -> dict:
    changes = {}
    for name in TEXT_FIELDS:
        if name not in fields:
            continue
        box = getattr(data, name)
        new_text = box.text if box else ""
        if new_text != open_text(getattr(customer, name)):
            setattr(customer, name, seal_text(new_text))
            changes[name] = (None, None)
    return changes


@transaction.atomic
def update_customer(user: User, customer_id: UUID, data: CustomerPatch) -> Customer:
    customer = lock_customer(user, customer_id, "edit")
    fields = data.model_fields_set
    changes = _plain_changes(customer, data, fields) | _text_changes(customer, data, fields)
    if changes:
        customer.updated_at = timezone.now()
        customer.save()
        history.log_all(customer.subject, user, changes)
        audit(user, "customer_updated", str(customer.id), fields=sorted(changes))
        notices.emit_customer("customer.updated", customer, user, fields=sorted(changes))
    mark_seen(user, customer.subject)
    return customer


def _members_state(customer: Customer) -> dict[int, str]:
    return dict(CustomerMember.objects.filter(customer=customer, active=True).values_list("user_id", "role"))


def _sync_members(customer: Customer, wanted: dict[int, str], actor: User) -> None:
    """Make exactly `wanted` the active members; others are deactivated, never deleted."""
    rows = {m.user_id: m for m in CustomerMember.objects.filter(customer=customer)}
    for uid, role in wanted.items():
        row = rows.get(uid)
        if row is None:
            CustomerMember.objects.create(customer=customer, user_id=uid, role=role, added_by=actor)
        elif not row.active or row.role != role:
            if not row.active:
                row.added_by, row.at = actor, timezone.now()
            row.active, row.role = True, role
            row.save()
    for uid, row in rows.items():
        if uid not in wanted and row.active:
            row.active = False
            row.save(update_fields=["active"])


@transaction.atomic
def set_members(user: User, customer_id: UUID, members: list[MemberIn]) -> Customer:
    customer = lock_customer(user, customer_id, "members")
    if all(m.user_id != customer.owner_id for m in members):
        raise HttpError(422, "The owner cannot be removed")
    wanted = checked_members(customer.owner_id, members)
    before = _members_state(customer)
    if before == wanted:
        return customer
    _sync_members(customer, wanted, user)
    added = sorted(set(wanted) - set(before))
    history.log(customer.subject, user, "members", sorted(before.items()), sorted(wanted.items()))
    customer.updated_at = timezone.now()
    customer.save(update_fields=["updated_at"])
    audit(user, "customer_members_changed", str(customer.id), added=len(added), total=len(wanted))
    if added:
        notices.emit_customer("customer.member.added", customer, user, user_ids=added)
        notices.notify_added(added, customer, user)
    notices.emit_customer("customer.updated", customer, user, fields=["members"])
    return customer
