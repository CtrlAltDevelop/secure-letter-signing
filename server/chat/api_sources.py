"""`GET /projects/{id}/chat` and `GET /customers/{id}/chat`: the group conversation mirroring that file members."""
from uuid import UUID

from django.shortcuts import get_object_or_404
from ninja import Router
from ninja.errors import HttpError

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, user_of
from workspace import registry

from . import mirror, service
from .schemas import ConversationOut
from .serializers import conversation_outs

router = Router(tags=["chat"], auth=BearerAuth())


@router.get("/projects/{uuid:project_id}/chat", response={200: ConversationOut, 404: Detail})
def project_chat(request, project_id: UUID):
    from projects import rules
    from projects.models import Project

    service.gate()
    registry.require_module("projects")
    user = user_of(request)
    project = get_object_or_404(Project.objects.select_related("subject", "owner"), pk=project_id)
    if not rules.can(user, project, "see"):
        raise HttpError(404, "Not found")
    conv = mirror.ensure_chat(user, project=project)
    return conversation_outs(user, [conv], detail=True)[0]


@router.get("/customers/{uuid:customer_id}/chat", response={200: ConversationOut, 404: Detail})
def customer_chat(request, customer_id: UUID):
    from crm import rules
    from crm.models import Customer

    service.gate()
    registry.require_module("crm")
    user = user_of(request)
    customer = get_object_or_404(Customer.objects.select_related("subject", "owner"), pk=customer_id)
    if not rules.can(user, customer, "see"):
        raise HttpError(404, "Not found")
    conv = mirror.ensure_chat(user, customer=customer)
    return conversation_outs(user, [conv], detail=True)[0]
