"""Project groups (mounted at /api/project-groups): organisation groups are run by the manager, personal ones by
their owner. Groups are deactivated, never deleted."""
from django.db import transaction
from django.db.models import Max, Q
from django.shortcuts import get_object_or_404
from ninja import Router
from ninja.errors import HttpError

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, user_of
from accounts.models import User

from . import group_access, service
from .models import ProjectGroup
from .schemas import GroupAccessIn, GroupAccessOut, GroupIn, GroupOut, GroupPatch

router = Router(tags=["projects"], auth=BearerAuth())
RANK_GAP = service.RANK_GAP


def _out(g: ProjectGroup) -> GroupOut:
    return GroupOut(id=g.id, name=g.name, scope="personal" if g.owner_id else "org", rank=g.rank, active=g.active)


def _visible(user: User):
    return ProjectGroup.objects.filter(Q(owner__isnull=True) | Q(owner=user))


@router.get("", response=list[GroupOut])
def list_groups(request, include_inactive: bool = False):
    service.gate()
    rows = _visible(user_of(request))
    if not include_inactive:
        rows = rows.filter(active=True)
    return [_out(g) for g in rows.order_by("rank", "id")]


@router.post("", response={201: GroupOut, 403: Detail, 422: Detail})
@transaction.atomic
def create(request, data: GroupIn):
    service.gate()
    user = user_of(request)
    if data.scope == "org" and not user.is_manager:
        raise HttpError(403, "Only the manager can manage organisation groups")
    owner = None if data.scope == "org" else user
    top = ProjectGroup.objects.filter(owner=owner).aggregate(m=Max("rank"))["m"] or 0
    return 201, _out(ProjectGroup.objects.create(name=data.name.strip(), owner=owner, rank=top + RANK_GAP))


@router.patch("/{int:group_id}", response={200: GroupOut, 403: Detail, 404: Detail, 422: Detail})
def patch(request, group_id: int, data: GroupPatch):
    service.gate()
    user = user_of(request)
    group = get_object_or_404(_visible(user), pk=group_id)
    if group.owner_id is None and not user.is_manager:
        raise HttpError(403, "Only the manager can manage organisation groups")
    for name in ("name", "rank", "active"):
        value = getattr(data, name)
        if name in data.model_fields_set and value is not None:
            setattr(group, name, value.strip() if name == "name" else value)
    group.save()
    return _out(group)


@router.put("/{int:group_id}/access", response={200: GroupAccessOut, 403: Detail, 404: Detail, 422: Detail})
def set_access(request, group_id: int, data: GroupAccessIn):
    """Manager only: add / change the role of / deactivate users on every project of an organisation group."""
    service.gate()
    user = user_of(request)
    if not user.is_manager:
        raise HttpError(403, "Only the manager can manage organisation groups")
    return group_access.apply(user, group_id, data)
