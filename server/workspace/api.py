"""Shared workspace endpoints: module list, labels, subject labels, workspace event replay."""
from uuid import UUID

from django.db import IntegrityError, transaction
from django.db.models import Q
from django.shortcuts import get_object_or_404
from ninja import Field, Router, Schema
from ninja.errors import HttpError

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, user_of
from accounts.models import User

from . import events, registry
from .access import access_to, my_label_ids, visible_labels
from .api_bookmarks import router as bookmarks_router
from .api_calendar import router as calendar_router
from .api_mentions import router as mentions_router
from .api_reminders import router as reminders_router
from .api_transfer import router as transfer_router
from .api_video import router as video_router
from .api_subjects import router as subjects_router
from .models import Label, SubjectLabel

router = Router(tags=["workspace"], auth=BearerAuth())
COLOR_MAX = 31
DUPLICATE = "A label with this name already exists"


class ModuleOut(Schema):
    code: str
    enabled: bool


class ModulesOut(Schema):
    plan: str
    modules: list[ModuleOut]


class LabelOut(Schema):
    id: int
    name: str
    color: int
    scope: str
    active: bool


class LabelIn(Schema):
    name: str = Field(min_length=1, max_length=60)
    color: int = Field(0, ge=0, le=COLOR_MAX)
    scope: str = Field(pattern="^(org|personal)$")


class LabelPatch(Schema):
    name: str | None = Field(None, min_length=1, max_length=60)
    color: int | None = Field(None, ge=0, le=COLOR_MAX)
    active: bool | None = None


class LabelIdsIn(Schema):
    label_ids: list[int] = Field(max_length=200)


class LabelIdsOut(Schema):
    label_ids: list[int]


def _out(label: Label) -> LabelOut:
    return LabelOut(id=label.id, name=label.name, color=label.color, scope=label.scope, active=label.active)


@router.get("/me/modules", response=ModulesOut)
def my_modules(request):
    enabled = registry.enabled_modules()
    return ModulesOut(plan=registry.PLAN, modules=[ModuleOut(code=c, enabled=c in enabled)
                                                    for c in registry.module_codes()])


@router.get("/labels", response=list[LabelOut])
def list_labels(request, include_inactive: bool = False):
    rows = visible_labels(user_of(request))
    if not include_inactive:
        rows = rows.filter(active=True)
    return [_out(x) for x in rows.order_by("scope", "name", "id")]


def _name_taken(scope: str, owner: User | None, name: str, exclude_id: int | None = None) -> bool:
    rows = Label.objects.filter(owner=owner if scope == Label.PERSONAL else None, name=name)
    return rows.exclude(pk=exclude_id).exists()


@router.post("/labels", response={201: LabelOut, 403: Detail, 409: Detail})
def create_label(request, data: LabelIn):
    user = user_of(request)
    if data.scope == Label.ORG and not user.is_manager:
        raise HttpError(403, "Only the manager can create organisation labels")
    owner = user if data.scope == Label.PERSONAL else None
    name = data.name.strip()
    if not name:
        raise HttpError(422, "Name is required")
    if _name_taken(data.scope, owner, name):
        raise HttpError(409, DUPLICATE)
    try:
        with transaction.atomic():
            label = Label.objects.create(scope=data.scope, owner=owner, name=name, color=data.color)
    except IntegrityError as exc:  # concurrent duplicate
        raise HttpError(409, DUPLICATE) from exc
    return 201, _out(label)


@router.patch("/labels/{int:label_id}", response={200: LabelOut, 403: Detail, 409: Detail})
def update_label(request, label_id: int, data: LabelPatch):
    user = user_of(request)
    label = get_object_or_404(visible_labels(user), pk=label_id)
    if label.scope == Label.ORG and not user.is_manager:
        raise HttpError(403, "Only the manager can change organisation labels")
    if data.name is not None:
        name = data.name.strip()
        if not name:
            raise HttpError(422, "Name is required")
        if name != label.name and _name_taken(label.scope, label.owner, name, label.id):
            raise HttpError(409, DUPLICATE)
        label.name = name
    if data.color is not None:
        label.color = data.color
    if data.active is not None:
        label.active = data.active
    try:
        with transaction.atomic():
            label.save()
    except IntegrityError as exc:
        raise HttpError(409, DUPLICATE) from exc
    return _out(label)


@router.put("/subjects/{uuid:subject_id}/labels", response={200: LabelIdsOut, 403: Detail, 422: Detail})
@transaction.atomic
def set_subject_labels(request, subject_id: UUID, data: LabelIdsIn):
    """Replace the caller's view of the subject's labels: org labels plus the caller's own personal ones.
    Other people's personal labels are never touched."""
    user = user_of(request)
    subject = access_to(user, subject_id, "label").subject
    wanted = set(data.label_ids)
    found = set(visible_labels(user).filter(pk__in=wanted, active=True).values_list("pk", flat=True))
    if found != wanted:
        raise HttpError(422, "Unknown or inactive label")
    rows = {r.label_id: r for r in SubjectLabel.objects.select_for_update().select_related("label")
            .filter(subject=subject).filter(Q(label__scope=Label.ORG) | Q(label__owner=user))}
    for label_id, row in rows.items():
        if row.label.active and row.active != (label_id in wanted):
            row.active = label_id in wanted
            row.save(update_fields=["active"])
    for label_id in wanted - rows.keys():
        SubjectLabel.objects.create(subject=subject, label_id=label_id, added_by=user)
    return LabelIdsOut(label_ids=my_label_ids(user, subject))


@router.get("/events/w", response=list[dict])
def workspace_events(request, after: int = 0, limit: int = events.REPLAY_MAX):
    return events.replay_events(user_of(request), max(after, 0), limit)


router.add_router("", subjects_router)
router.add_router("", reminders_router)
router.add_router("", mentions_router)
router.add_router("", transfer_router)
router.add_router("", calendar_router)
router.add_router("", bookmarks_router)
router.add_router("", video_router)
