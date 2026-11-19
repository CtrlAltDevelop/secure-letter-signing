"""Create meetings (optionally from a template) and edit their fields."""
from uuid import UUID

from django.db import transaction
from ninja.errors import HttpError

from accounts.models import User, audit
from crm import service as crm_service
from crm import timeline as crm_timeline
from projects import membership
from projects.models import Project
from workspace.models import Subject
from workspace.seen import mark_seen
from workspace.textbox import open_text, seal_text

from . import attendees, content, history, notices, store, templates
from .models import Meeting
from .schemas import AttendeeIn, MeetingIn, MeetingPatch

PLAIN_FIELDS = ("title", "kind", "location", "starts_at", "ends_at")


def check_times(starts_at, ends_at) -> None:
    if starts_at and ends_at and ends_at < starts_at:
        raise HttpError(422, "The meeting ends before it starts")


def checked_project(user: User, project_id: UUID | None) -> Project | None:
    """The project, if the user is a member (404 otherwise, like an invisible project)."""
    if project_id is None:
        return None
    project = Project.objects.filter(pk=project_id).first()
    if project is None or membership.role_in(user, project.pk) is None:
        raise HttpError(404, "Not found")
    return project


def _merged(data: MeetingIn, template) -> dict:
    base = template.data if template else {}
    entries = data.attendees
    if entries is None:
        entries = [AttendeeIn(**a) for a in base.get("attendees", [])]
    return {
        "kind": data.kind or base.get("kind", Meeting.SIMPLE),
        "location": data.location if data.location is not None else base.get("location", ""),
        "description": data.description.text if data.description is not None else base.get("description", ""),
        "attendees": entries,
    }


@transaction.atomic
def create_meeting(user: User, data: MeetingIn) -> Meeting:
    template = templates.usable(user, data.template_id) if data.template_id else None
    values = _merged(data, template)
    title = (data.title or (template.name if template else "")).strip()
    if not title:
        raise HttpError(422, "A title is required")
    check_times(data.starts_at, data.ends_at)
    if data.status == Meeting.SCHEDULED and data.starts_at is None:
        raise HttpError(422, "A scheduled meeting needs a start time")
    project = checked_project(user, data.project_id)
    customer = crm_service.linkable(user, data.customer_id) if data.customer_id else None
    attendees.validate(values["kind"], values["attendees"])
    subject = Subject.objects.create(module=notices.MODULE, kind="meeting")
    meeting = Meeting.objects.create(
        subject=subject, title=title, kind=values["kind"], location=values["location"].strip(),
        starts_at=data.starts_at, ends_at=data.ends_at, description=seal_text(values["description"]), creator=user,
        project=project, template=template, status=data.status, customer=customer)
    added = attendees.apply(meeting, user, values["attendees"])
    history.log(subject, user, "status", None, meeting.status)
    if customer:
        crm_timeline.record(customer, "meeting", f"Meeting linked: {meeting.title}", user, subject)
    audit(user, "meeting_created", str(meeting.id), kind=meeting.kind, status=meeting.status)
    mark_seen(user, subject)
    notices.emit_meeting("meeting.created", meeting, user)
    if meeting.status == Meeting.SCHEDULED:
        notices.notify_users(added, "meeting.invited", meeting, user)
    return meeting


def _field_changes(user: User, meeting: Meeting, data: MeetingPatch, fields: set[str]) -> dict:
    changes = {}
    for name in PLAIN_FIELDS:
        if name not in fields:
            continue
        value = getattr(data, name)
        if name in ("title", "location"):
            value = (value or "").strip()
        if name in ("title", "kind") and not value:
            raise HttpError(422, f"{name} cannot be empty")
        if getattr(meeting, name) != value:
            changes[name] = (getattr(meeting, name), value)
            setattr(meeting, name, value)
    if "project_id" in fields and data.project_id != meeting.project_id:
        project = checked_project(user, data.project_id)
        changes["project"] = (str(meeting.project_id) if meeting.project_id else None,
                              str(project.pk) if project else None)
        meeting.project = project
    if "customer_id" in fields and data.customer_id != meeting.customer_id:
        customer = crm_service.linkable(user, data.customer_id) if data.customer_id else None
        changes["customer"] = (str(meeting.customer_id) if meeting.customer_id else None,
                               str(customer.pk) if customer else None)
        meeting.customer = customer
        if customer:
            crm_timeline.record(customer, "meeting", f"Meeting linked: {meeting.title}", user, meeting.subject)
    return changes


def _edit_description(user: User, meeting: Meeting, data: MeetingPatch) -> dict:
    new_text = data.description.text if data.description else ""
    if new_text == open_text(meeting.description):
        return {}
    store.require(user, meeting, "record")
    content.require_minutes_editable(meeting)
    meeting.description = seal_text(new_text)
    return {"description": (None, None)}


@transaction.atomic
def update_meeting(user: User, meeting_id: UUID, data: MeetingPatch) -> Meeting:
    meeting = store.lock_meeting(user, meeting_id)
    fields = data.model_fields_set
    changes: dict = {}
    if fields - {"description"}:
        store.require(user, meeting, "manage")
        store.require_status(meeting, Meeting.DRAFT, Meeting.SCHEDULED)
        old_kind = meeting.kind
        changes.update(_field_changes(user, meeting, data, fields))
        if meeting.kind != old_kind:
            attendees.validate(meeting.kind, attendees.current_entries(meeting))
        check_times(meeting.starts_at, meeting.ends_at)
    if "description" in fields:
        changes.update(_edit_description(user, meeting, data))
    if changes:
        store.save(meeting)
        history.log_all(meeting.subject, user, changes)
        notices.emit_meeting("meeting.updated", meeting, user, fields=sorted(changes))
    mark_seen(user, meeting.subject)
    return meeting
