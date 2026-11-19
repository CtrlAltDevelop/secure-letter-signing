"""Access to a subject through its module's own rules, shared by every generic endpoint."""
from dataclasses import dataclass
from typing import Any
from uuid import UUID

from django.db.models import Q, QuerySet
from django.shortcuts import get_object_or_404
from ninja.errors import HttpError

from accounts.models import User

from . import registry
from .models import Label, Subject, SubjectLabel


@dataclass(frozen=True)
class Access:
    subject: Subject
    spec: registry.ModuleSpec
    obj: Any

    @property
    def title(self) -> str:
        return self.spec.title(self.obj) if self.spec.title else ""


def access_for(user: User, subject: Subject, action: str) -> Access:
    """404 when the module is off or the user cannot see the subject; 403 when seeing is allowed but `action` is not."""
    registry.require_module(subject.module)
    spec = registry.get(subject.module)
    obj = spec.resolve(subject) if spec else None
    if obj is None or not spec.can(user, obj, "see"):
        raise HttpError(404, "Not found")
    if not spec.can(user, obj, action):
        raise HttpError(403, "Permission denied")
    return Access(subject, spec, obj)


def access_to(user: User, subject_id: UUID, action: str) -> Access:
    return access_for(user, get_object_or_404(Subject, pk=subject_id), action)


def visible_labels(user: User) -> QuerySet[Label]:
    return Label.objects.filter(Q(scope=Label.ORG) | Q(owner=user))


def my_label_ids(user: User, subject: Subject) -> list[int]:
    rows = SubjectLabel.objects.filter(subject=subject, active=True, label__active=True).filter(
        Q(label__scope=Label.ORG) | Q(label__owner=user))
    return sorted(rows.values_list("label_id", flat=True))
