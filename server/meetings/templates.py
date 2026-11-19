"""Meeting templates: organisation-wide (manager only) or personal. Never deleted, only deactivated."""
from django.db.models import Q, QuerySet
from django.shortcuts import get_object_or_404
from ninja.errors import HttpError

from accounts.models import User

from .models import MeetingTemplate
from .schemas import TemplateData, TemplateIn, TemplateOut, TemplatePatch


def visible(user: User) -> QuerySet[MeetingTemplate]:
    return MeetingTemplate.objects.filter(Q(owner__isnull=True) | Q(owner=user))


def out(t: MeetingTemplate) -> TemplateOut:
    return TemplateOut(id=t.id, name=t.name, scope="personal" if t.owner_id else "org", owner_id=t.owner_id,
                       data=t.data, active=t.active)


def _check_users(data: TemplateData) -> None:
    ids = {a.user_id for a in data.attendees}
    if len(ids) != len(data.attendees) or User.objects.filter(pk__in=ids, is_active=True).count() != len(ids):
        raise HttpError(422, "Unknown, inactive or duplicate user in the template")


def create(user: User, data: TemplateIn) -> MeetingTemplate:
    if data.scope == "org" and not user.is_manager:
        raise HttpError(403, "Only the manager can create organisation templates")
    _check_users(data.data)
    return MeetingTemplate.objects.create(owner=user if data.scope == "personal" else None, name=data.name.strip(),
                                          data=data.data.model_dump())


def update(user: User, template_id: int, data: TemplatePatch) -> MeetingTemplate:
    template = get_object_or_404(visible(user), pk=template_id)
    if template.owner_id is None and not user.is_manager:
        raise HttpError(403, "Only the manager can change organisation templates")
    if data.name is not None:
        template.name = data.name.strip()
    if data.data is not None:
        _check_users(data.data)
        template.data = data.data.model_dump()
    if data.active is not None:
        template.active = data.active
    template.save()
    return template


def usable(user: User, template_id: int) -> MeetingTemplate:
    template = visible(user).filter(pk=template_id, active=True).first()
    if template is None:
        raise HttpError(422, "Unknown or inactive template")
    return template
