"""The company manager adjusts one user's membership of projects, customer files and chat groups.

Rows are switched on/off (`active`) or re-roled, never deleted. Project and customer chats follow their source on
their own (chat signals); only free-standing group/channel chats are edited here. Customer files carry no names here:
the manager sees ids and roles only.
"""
from uuid import UUID

from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja import Router, Schema
from ninja.errors import HttpError

from .auth import BearerAuth, require_manager
from .models import User, audit

router = Router(tags=["manager"], auth=BearerAuth())
PROJECT_ROLES = ("manager", "member", "viewer")
CHAT_ROLES = ("admin", "member")


class AccessRowIn(Schema):
    id: UUID
    active: bool = True
    role: str | None = None  # keep the current role (new rows: member) when omitted


class AccessIn(Schema):
    projects: list[AccessRowIn] = []
    customers: list[AccessRowIn] = []
    conversations: list[AccessRowIn] = []


class AccessRowOut(Schema):
    id: UUID
    role: str
    active: bool
    name: str = ""  # projects and group chats only
    kind: str = ""  # chats only


class AccessOut(Schema):
    projects: list[AccessRowOut]
    customers: list[AccessRowOut]
    conversations: list[AccessRowOut]


def _chat_rows(user: User):
    from chat.models import ConversationMember

    return ConversationMember.objects.filter(
        user=user, conversation__kind__in=("group", "channel"), conversation__project__isnull=True,
        conversation__customer_ref__isnull=True).select_related("conversation")


def _access_of(user: User) -> AccessOut:
    from crm.models import CustomerMember
    from projects.models import ProjectMember

    projects = ProjectMember.objects.filter(user=user).select_related("project").order_by("project__name")
    return AccessOut(
        projects=[AccessRowOut(id=m.project_id, role=m.role, active=m.active, name=m.project.name) for m in projects],
        customers=[AccessRowOut(id=m.customer_id, role=m.role, active=m.active)
                   for m in CustomerMember.objects.filter(user=user).order_by("at")],
        conversations=[AccessRowOut(id=m.conversation_id, role=m.role, active=m.active, name=m.conversation.name,
                                    kind=m.conversation.kind) for m in _chat_rows(user).order_by("conversation__name")],
    )


def _role(row: AccessRowIn, current: str | None, allowed: tuple[str, ...]) -> str:
    role = row.role or current or "member"
    if role not in allowed:
        raise HttpError(422, "Unknown role")
    return role


def _apply(model, fk: str, obj, user: User, row: AccessRowIn, manager: User, allowed, *, owner_id=None) -> bool:
    """Create or update one membership row; True when anything changed."""
    existing = model.objects.filter(**{fk: obj}, user=user).first()
    role = _role(row, existing.role if existing else None, allowed)
    if owner_id == user.id and (not row.active or role != "manager"):
        raise HttpError(422, "The owner cannot be removed or demoted")
    if existing is None:
        if row.active:
            extra = {"added_by": manager} if hasattr(model, "added_by") else {}
            model.objects.create(**{fk: obj}, user=user, role=role, **extra)
            return True
        return False
    if existing.active == row.active and existing.role == role:
        return False
    existing.active, existing.role = row.active, role
    if row.active and hasattr(existing, "added_by"):
        existing.added_by, existing.at = manager, timezone.now()
    existing.save()
    return True


def _project_rows(manager: User, user: User, rows: list[AccessRowIn]) -> int:
    from projects.models import Project, ProjectMember

    n = 0
    for r in rows:
        project = get_object_or_404(Project, pk=r.id)
        n += _apply(ProjectMember, "project", project, user, r, manager, PROJECT_ROLES, owner_id=project.owner_id)
    return n


def _customer_rows(manager: User, user: User, rows: list[AccessRowIn]) -> int:
    from crm.models import Customer, CustomerMember

    if rows and user.is_guest:
        raise HttpError(422, "Guests cannot be added to customer files")
    n = 0
    for r in rows:
        customer = get_object_or_404(Customer, pk=r.id)
        n += _apply(CustomerMember, "customer", customer, user, r, manager, PROJECT_ROLES, owner_id=customer.owner_id)
    return n


def _chat_row_changes(manager: User, user: User, rows: list[AccessRowIn]) -> int:
    from chat.models import Conversation, ConversationMember

    n = 0
    for r in rows:
        conv = get_object_or_404(Conversation, pk=r.id, kind__in=("group", "channel"), project__isnull=True,
                                 customer_ref__isnull=True)
        n += _apply(ConversationMember, "conversation", conv, user, r, manager, CHAT_ROLES)
    return n


@router.get("/users/{user_id}/access", response=AccessOut)
def get_access(request, user_id: int):
    require_manager(request)
    return _access_of(get_object_or_404(User, pk=user_id))


@router.put("/users/{user_id}/access", response=AccessOut)
@transaction.atomic
def set_access(request, user_id: int, data: AccessIn):
    """Each listed row is created, switched on/off or re-roled; unlisted rows stay as they are."""
    manager = require_manager(request)
    target = get_object_or_404(User, pk=user_id, is_active=True)
    changed = {
        "projects": _project_rows(manager, target, data.projects),
        "customers": _customer_rows(manager, target, data.customers),
        "conversations": _chat_row_changes(manager, target, data.conversations),
    }
    audit(manager, "user_access_changed", str(target.id), **changed)
    return _access_of(target)
