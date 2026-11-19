"""Secretariat (dabirkhaneh) register: incoming external letters and outgoing numbers for published letters."""
from uuid import UUID

from django.db import IntegrityError, transaction
from django.db.models import Q, QuerySet
from django.shortcuts import get_object_or_404
from ninja.errors import HttpError

from accounts.models import User, audit
from workspace import events as wevents
from workspace import registry
from workspace.access import my_label_ids
from workspace.models import Subject
from workspace.schemas import TextBody, user_ref
from workspace.textbox import open_text, seal_text

from . import notices, numbering, rules
from .models import CustomerLink, Letter, SecretariatEntry
from .module import ENTRY_KIND
from .schemas import EntryIn, EntryOut, EntryPatch

MAX_PAGE = 200
TEXT_FIELDS = ("title", "party_name", "party_ref")


def customer_refs(subject_id) -> list[UUID]:
    rows = CustomerLink.objects.filter(subject_id=subject_id, active=True, customer_ref__isnull=False)
    return sorted(rows.values_list("customer_ref", flat=True))


def entry_out(user: User, e: SecretariatEntry) -> EntryOut:
    return EntryOut(
        id=e.id, subject_id=e.subject_id, direction=e.direction, number=e.number, jalali_year=e.jalali_year, seq=e.seq,
        registered_at=e.registered_at, registered_by=user_ref(e.registered_by), title=e.title, party_name=e.party_name,
        party_ref=e.party_ref, letter_id=e.letter_id, summary=TextBody(text=open_text(e.summary)),
        customer_refs=customer_refs(e.subject_id), label_ids=my_label_ids(user, e.subject), active=e.active)


def _numbered_letter(user: User, data: EntryIn) -> Letter | None:
    if data.letter_id is None:
        return None
    if data.direction != SecretariatEntry.OUT:
        raise HttpError(422, "Only outgoing entries can point to a letter")
    letter = get_object_or_404(Letter.objects.select_for_update(), pk=data.letter_id)
    if not rules.can_see(user, letter):
        raise HttpError(404, "Letter not found")
    if letter.status != Letter.PUBLISHED:
        raise HttpError(409, "Only a published letter gets a number")
    if SecretariatEntry.objects.filter(letter=letter).exists():
        raise HttpError(409, "This letter already has a number")
    return letter


def _title_of(data: EntryIn, letter: Letter | None) -> str:
    title = data.title.strip() or (letter.title if letter else "")
    if not title:
        raise HttpError(422, "A title is required")
    return title


@transaction.atomic
def register(user: User, data: EntryIn) -> SecretariatEntry:
    letter = _numbered_letter(user, data)
    title = _title_of(data, letter)
    subject = Subject.objects.create(module="letters", kind=ENTRY_KIND)
    year, seq, number = numbering.next_number(data.direction)
    try:
        with transaction.atomic():
            entry = SecretariatEntry.objects.create(
                subject=subject, direction=data.direction, jalali_year=year, seq=seq, number=number, registered_by=user,
                title=title, party_name=data.party_name.strip(), party_ref=data.party_ref.strip(), letter=letter,
                summary=seal_text(data.summary.strip()))
    except IntegrityError as exc:  # a concurrent request numbered the same letter
        raise HttpError(409, "This letter already has a number") from exc
    audit(user, "secretariat_registered", str(entry.id), direction=entry.direction, number=number,
          letter=str(letter.id) if letter else None)
    _announce(user, entry, letter)
    return entry


def _announce(user: User, entry: SecretariatEntry, letter: Letter | None) -> None:
    holders = set(User.objects.filter(is_active=True, grants__code=rules.SECRETARIAT).values_list("id", flat=True))
    wevents.emit("letters", "secretariat.registered", entry.subject, entry.title, user, holders - {user.id},
                 entry_id=str(entry.id), direction=entry.direction, number=entry.number)
    if letter is not None:
        notices.history(letter.subject, user, "secretariat_number", None,
                        {"number": entry.number, "entry_id": str(entry.id)})
        notices.announce(letter, "numbered", user, entry_id=str(entry.id), number=entry.number)


def entries(direction: str, q: str, year: int | None) -> QuerySet[SecretariatEntry]:
    rows = SecretariatEntry.objects.filter(active=True).select_related("registered_by", "subject")
    if direction in (SecretariatEntry.IN, SecretariatEntry.OUT):
        rows = rows.filter(direction=direction)
    if year:
        rows = rows.filter(jalali_year=year)
    if q.strip():
        needle = q.strip()
        rows = rows.filter(Q(title__icontains=needle) | Q(party_name__icontains=needle)
                           | Q(party_ref__icontains=needle) | Q(number__icontains=needle))
    return rows.order_by("-registered_at", "-id")


def page(rows: QuerySet, limit: int, offset: int) -> list:
    start = max(offset, 0)
    return list(rows[start : start + max(min(limit, MAX_PAGE), 0)])


@transaction.atomic
def update(user: User, entry_id: UUID, data: EntryPatch) -> SecretariatEntry:
    entry = get_object_or_404(SecretariatEntry.objects.select_for_update().select_related("registered_by", "subject"),
                              pk=entry_id, active=True)
    changes = data.model_dump(exclude_unset=True)
    for field in TEXT_FIELDS:
        new = (changes.get(field) or "").strip() if field in changes else None
        if new is not None and new != getattr(entry, field):
            notices.history(entry.subject, user, field, getattr(entry, field), new)
            setattr(entry, field, new)
    summary = changes.get("summary")
    if summary is not None and summary.strip() != open_text(entry.summary):
        notices.history(entry.subject, user, "summary", {"changed": True}, {"changed": True})
        entry.summary = seal_text(summary.strip())
    entry.save()
    audit(user, "secretariat_updated", str(entry.id), fields=sorted(changes))
    return entry


def _checked_refs(user: User, refs: set[UUID], before: set[UUID]) -> set[UUID]:
    """Newly requested refs must be customer files the caller is a member of (422); links the caller cannot see stay."""
    from crm import membership

    fresh = refs - before
    if fresh:
        if "crm" not in registry.enabled_modules() or membership.visible_ids(user, fresh) != fresh:
            raise HttpError(422, "Unknown customer")
    hidden = before - membership.visible_ids(user, before)
    return (refs & before) | fresh | hidden


def _record_links(user: User, subject: Subject, added: set[UUID]) -> None:
    from crm import timeline
    from crm.models import Customer

    spec = registry.get("letters")
    obj = spec.resolve(subject) if spec else None
    title = obj.title if obj else ""
    for customer in Customer.objects.filter(pk__in=added).select_related("subject"):
        timeline.record(customer, "letter", f"Letter linked: {title}", user, subject)


@transaction.atomic
def set_customers(user: User, subject: Subject, refs: list[UUID]) -> list[UUID]:
    """Replace the customer links of a subject (links are deactivated, never deleted).

    Requested customers must be files the caller is a member of; links to files the caller cannot see are kept.
    """
    rows = {r.customer_ref: r for r in CustomerLink.objects.select_for_update()
            .filter(subject=subject, customer_ref__isnull=False)}
    before = {ref for ref, row in rows.items() if row.active}
    wanted = _checked_refs(user, set(refs), before)
    for ref, row in rows.items():
        if row.active != (ref in wanted):
            CustomerLink.objects.filter(pk=row.pk).update(active=ref in wanted, added_by=user)
    for ref in wanted - rows.keys():
        CustomerLink.objects.create(subject=subject, customer_ref=ref, added_by=user)
    if before != wanted:
        audit(user, "customers_linked", str(subject.id), added=len(wanted - before), removed=len(before - wanted))
        notices.history(subject, user, "customers", sorted(map(str, before)), sorted(map(str, wanted)))
        _record_links(user, subject, wanted - before)
    return customer_refs(subject.id)
