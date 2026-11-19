"""Task templates API: `/task-templates` and `POST /tasks/from-template` (mounted at the API root)."""
from ninja import Router

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, user_of
from workspace import registry

from . import templates
from .api import _out
from .schemas import TaskOut
from .template_schemas import FromTemplateIn, TemplateIn, TemplateOut, TemplatePatch

router = Router(tags=["tasks"], auth=BearerAuth())
ERRORS = {403: Detail, 404: Detail, 409: Detail, 422: Detail}


@router.get("/task-templates", response=list[TemplateOut])
def list_templates(request, include_inactive: bool = False):
    registry.require_module("tasks")
    rows = templates.visible(user_of(request))
    if not include_inactive:
        rows = rows.filter(active=True)
    return [templates.out(t) for t in rows.order_by("name", "id")]


@router.post("/task-templates", response={201: TemplateOut, **ERRORS})
def create_template(request, data: TemplateIn):
    registry.require_module("tasks")
    return 201, templates.out(templates.create(user_of(request), data))


@router.patch("/task-templates/{int:template_id}", response={200: TemplateOut, **ERRORS})
def patch_template(request, template_id: int, data: TemplatePatch):
    registry.require_module("tasks")
    return templates.out(templates.update(user_of(request), template_id, data))


@router.post("/tasks/from-template", response={201: TaskOut, **ERRORS})
def from_template(request, data: FromTemplateIn):
    registry.require_module("tasks")
    user = user_of(request)
    return 201, _out(user, templates.create_from_template(user, data))
