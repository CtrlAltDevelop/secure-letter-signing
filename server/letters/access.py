"""Shared endpoint helpers for the letters routers."""
from uuid import UUID

from django.shortcuts import get_object_or_404
from ninja.errors import HttpError

from accounts.models import User

from . import rules
from .models import Letter


def get_visible(user: User, letter_id: UUID) -> Letter:
    """The letter, or 404 (missing and invisible look the same)."""
    letter = get_object_or_404(Letter, pk=letter_id)
    if not rules.can_see(user, letter):
        raise HttpError(404, "Letter not found")
    return letter


def require(user: User, code: str) -> None:
    if code not in rules.grants_of(user):
        raise HttpError(403, "Permission denied")
