"""Meeting templates API (mounted at /api/meeting-templates)."""
from ninja import Router

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, user_of
from workspace import registry

from . import templates
from .schemas import TemplateIn, TemplateOut, TemplatePatch

router = Router(tags=["meetings"], auth=BearerAuth())
ERRORS = {403: Detail, 404: Detail, 422: Detail}


@router.get("", response=list[TemplateOut])
def list_templates(request, include_inactive: bool = False):
    registry.require_module("meetings")
    rows = templates.visible(user_of(request))
    if not include_inactive:
        rows = rows.filter(active=True)
    return [templates.out(t) for t in rows.order_by("name", "id")]


@router.post("", response={201: TemplateOut, **ERRORS})
def create_template(request, data: TemplateIn):
    registry.require_module("meetings")
    return 201, templates.out(templates.create(user_of(request), data))


@router.patch("/{int:template_id}", response={200: TemplateOut, **ERRORS})
def patch_template(request, template_id: int, data: TemplatePatch):
    registry.require_module("meetings")
    return templates.out(templates.update(user_of(request), template_id, data))
