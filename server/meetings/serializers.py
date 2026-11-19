"""Meeting -> MeetingBrief / MeetingOut."""
from collections.abc import Sequence

from django.db.models import Count, Q

from accounts.models import User
from crm import membership as crm_membership
from core import cryptoutil
from tasks.models import Task
from workspace.access import my_label_ids
from workspace.models import SeenBy
from workspace.schemas import user_ref
from workspace.textbox import open_text

from . import content, resolutions, rules, signing
from .models import Meeting, MeetingAttendee, MeetingMinutesSignature, Resolution
from .schemas import (AttendeeOut, CanOut, Counts, MeetingBrief, MeetingOut, ResolutionOut, SignatureOut, TextIn)


def _counts(meetings: Sequence[Meeting]) -> dict:
    rows = (Resolution.objects.filter(meeting__in=meetings, active=True).exclude(status=Resolution.CANCELLED)
            .values("meeting_id").annotate(total=Count("id"), done=Count("id", filter=Q(status=Resolution.DONE))))
    return {r["meeting_id"]: Counts(done=r["done"], total=r["total"]) for r in rows}


def _attendee_counts(meetings: Sequence[Meeting]) -> dict:
    rows = MeetingAttendee.objects.filter(meeting__in=meetings, active=True).values("meeting_id").annotate(n=Count("id"))
    return {r["meeting_id"]: r["n"] for r in rows}


def _my_roles(user: User, meetings: Sequence[Meeting]) -> dict:
    rows = MeetingAttendee.objects.filter(meeting__in=meetings, user=user, active=True)
    return dict(rows.values_list("meeting_id", "role"))


def briefs(user: User, meetings: Sequence[Meeting]) -> list[MeetingBrief]:
    counts, people, roles = _counts(meetings), _attendee_counts(meetings), _my_roles(user, meetings)
    customers = crm_membership.visible_names(user, [m.customer_id for m in meetings])
    seen = dict(SeenBy.objects.filter(user=user, subject_id__in=[m.subject_id for m in meetings])
                .values_list("subject_id", "last_at"))
    out = []
    for m in meetings:
        last = seen.get(m.subject_id)
        role = roles.get(m.id) or ("creator" if m.creator_id == user.id else None)
        out.append(MeetingBrief(
            id=m.id, subject_id=m.subject_id, title=m.title, kind=m.kind, status=m.status, location=m.location,
            starts_at=m.starts_at, ends_at=m.ends_at, project_id=m.project_id, creator_id=m.creator_id, my_role=role,
            customer_id=m.customer_id if m.customer_id in customers else None, customer_name=customers.get(m.customer_id),
            attendee_count=people.get(m.id, 0), resolutions=counts.get(m.id, Counts(done=0, total=0)),
            label_ids=my_label_ids(user, m.subject), unseen=last is None or m.updated_at > last,
            revision=m.revision, updated_at=m.updated_at))
    return out


def resolution_out(r: Resolution, tasks: dict) -> ResolutionOut:
    task = tasks.get(r.task_id)
    return ResolutionOut(id=r.id, text=open_text(r.text), due_at=r.due_at, status=r.status,
                         owner_ids=resolutions.owner_ids(r), task_id=r.task_id,
                         task_status=task.status if task else None, task_progress=task.progress if task else None,
                         created_at=r.created_at)


def signature_out(s: MeetingMinutesSignature, revision: int) -> SignatureOut:
    return SignatureOut(id=s.id, user=user_ref(s.user), decision=s.decision, note=s.note, method=s.method,
                        revision=s.revision, stale=s.revision != revision,
                        valid=cryptoutil.verify_seal(s.payload, s.seal), created_at=s.created_at)


def meeting_out(user: User, meeting: Meeting) -> MeetingOut:
    brief = briefs(user, [meeting])[0]
    attendees = MeetingAttendee.objects.filter(meeting=meeting, active=True).select_related("user").order_by("id")
    items = list(Resolution.objects.filter(meeting=meeting, active=True).order_by("id"))
    tasks = Task.objects.in_bulk([r.task_id for r in items if r.task_id])
    sigs = meeting.signatures.select_related("user").order_by("created_at", "id")
    is_present = attendees.filter(user=user, attendance=MeetingAttendee.PRESENT).exists()
    return MeetingOut(
        **brief.model_dump(), description=TextIn(text=open_text(meeting.description)), creator=user_ref(meeting.creator),
        attendees=[AttendeeOut(id=a.id, user=user_ref(a.user) if a.user else None, guest_name=a.guest_name,
                               role=a.role, attendance=a.attendance) for a in attendees],
        resolution_items=[resolution_out(r, tasks) for r in items],
        signatures=[signature_out(s, meeting.revision) for s in sigs], template_id=meeting.template_id,
        content_hash=content.content_hash(meeting), all_signed=signing.all_signed(meeting),
        can=CanOut(manage=rules.can_manage(meeting, user), record=rules.can_record(meeting, user),
                   run=rules.can_run(meeting, user), chair=rules.is_chair(meeting, user),
                   sign=is_present and meeting.status == Meeting.HELD
                   and not content.current_signatures(meeting).filter(user=user).exists(), comment=True),
        created_at=meeting.created_at)
