"""Seen-by marks: first and last time a user opened a subject."""
from django.db import transaction
from django.utils import timezone

from accounts.models import User

from .models import SeenBy, Subject


def mark_seen(user: User, subject: Subject) -> None:
    now = timezone.now()
    with transaction.atomic():
        if not SeenBy.objects.filter(subject=subject, user=user).update(last_at=now):
            SeenBy.objects.get_or_create(subject=subject, user=user, defaults={"first_at": now, "last_at": now})
