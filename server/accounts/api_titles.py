"""Company titles (job positions), manager only (mounted under /api/manage). Never deleted, only deactivated."""
from django.db.models import Count
from django.shortcuts import get_object_or_404
from ninja import Field, Router, Schema
from ninja.errors import HttpError

from .api_auth import Detail
from .auth import BearerAuth, require_manager
from .models import OrgTitle, User, audit
from .schemas import UserOut

router = Router(tags=["manager"], auth=BearerAuth())
ERRORS = {403: Detail, 404: Detail, 409: Detail, 422: Detail}
DUPLICATE = "A title with this name already exists"


class TitleIn(Schema):
    name: str = Field(min_length=1, max_length=100)


class TitlePatch(Schema):
    name: str | None = Field(None, min_length=1, max_length=100)
    active: bool | None = None


class TitleOut(Schema):
    id: int
    name: str
    active: bool
    members: int


class UserTitleIn(Schema):
    title_id: int | None = None  # null clears the title


def _out(title: OrgTitle, members: int | None = None) -> TitleOut:
    return TitleOut(id=title.id, name=title.name, active=title.active,
                    members=title.users.count() if members is None else members)


def _clean_name(raw: str, exclude_id: int | None = None) -> str:
    name = raw.strip()
    if not name:
        raise HttpError(422, "Name is required")
    if OrgTitle.objects.filter(name__iexact=name).exclude(pk=exclude_id).exists():
        raise HttpError(409, DUPLICATE)
    return name


@router.get("/titles", response=list[TitleOut])
def list_titles(request):
    require_manager(request)
    rows = OrgTitle.objects.annotate(n=Count("users")).order_by("name")
    return [_out(t, t.n) for t in rows]


@router.post("/titles", response={201: TitleOut, **ERRORS})
def create_title(request, data: TitleIn):
    manager = require_manager(request)
    title = OrgTitle.objects.create(name=_clean_name(data.name))
    audit(manager, "title_created", str(title.pk))
    return 201, _out(title, 0)


@router.patch("/titles/{int:title_id}", response={200: TitleOut, **ERRORS})
def update_title(request, title_id: int, data: TitlePatch):
    manager = require_manager(request)
    title = get_object_or_404(OrgTitle, pk=title_id)
    if data.name is not None:
        title.name = _clean_name(data.name, title.pk)
    if data.active is not None:
        title.active = data.active
    title.save()
    audit(manager, "title_changed", str(title.pk), active=title.active)
    return _out(title)


@router.put("/users/{int:user_id}/title", response={200: UserOut, **ERRORS})
def set_user_title(request, user_id: int, data: UserTitleIn):
    manager = require_manager(request)
    target = get_object_or_404(User, pk=user_id)
    title = get_object_or_404(OrgTitle, pk=data.title_id, active=True) if data.title_id is not None else None
    target.org_title = title
    target.save(update_fields=["org_title"])
    audit(manager, "user_title_set", target.email, title_id=title.pk if title else None)
    return UserOut.of(target)
