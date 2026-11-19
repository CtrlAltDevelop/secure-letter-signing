"""Secretariat register endpoints (`/secretariat`), restricted to holders of `letter.secretariat`."""
from uuid import UUID

from django.shortcuts import get_object_or_404
from ninja import Router
from ninja.errors import HttpError

from accounts.auth import BearerAuth, user_of
from accounts.models import User

from . import rules, secretariat
from .models import SecretariatEntry
from .schemas import CustomerRefsIn, CustomerRefsOut, EntryIn, EntryOut, EntryPatch

router = Router(tags=["secretariat"], auth=BearerAuth())


def _clerk(request) -> User:
    user = user_of(request)
    if not rules.has_secretariat(user):
        raise HttpError(403, "Permission denied")
    return user


def _entry(entry_id: UUID) -> SecretariatEntry:
    return get_object_or_404(SecretariatEntry.objects.select_related("registered_by", "subject"), pk=entry_id,
                             active=True)


@router.post("/entries", response={201: EntryOut})
def register_entry(request, data: EntryIn):
    user = _clerk(request)
    entry = secretariat.register(user, data)
    return 201, secretariat.entry_out(user, _entry(entry.pk))


@router.get("/entries", response=list[EntryOut])
def list_entries(request, direction: str = "", q: str = "", year: int | None = None, limit: int = 100,
                 offset: int = 0):
    user = _clerk(request)
    rows = secretariat.page(secretariat.entries(direction, q, year), limit, offset)
    return [secretariat.entry_out(user, e) for e in rows]


@router.get("/entries/{uuid:entry_id}", response=EntryOut)
def get_entry(request, entry_id: UUID):
    user = _clerk(request)
    return secretariat.entry_out(user, _entry(entry_id))


@router.patch("/entries/{uuid:entry_id}", response=EntryOut)
def patch_entry(request, entry_id: UUID, data: EntryPatch):
    user = _clerk(request)
    secretariat.update(user, entry_id, data)
    return secretariat.entry_out(user, _entry(entry_id))


@router.put("/entries/{uuid:entry_id}/customers", response=CustomerRefsOut)
def set_entry_customers(request, entry_id: UUID, data: CustomerRefsIn):
    user = _clerk(request)
    return CustomerRefsOut(customer_refs=secretariat.set_customers(user, _entry(entry_id).subject, data.customer_refs))
