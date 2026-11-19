"""`GET /monitor/meetings`: meetings in the period (identifying briefs and counts, never descriptions or minutes)."""
from django.db.models import Count, Q

from meetings.models import Meeting, MeetingAttendee, Resolution

from .period import Period

MAX_LIMIT = 200


def report(period: Period, project: str, project_id: str, limit: int, offset: int) -> dict:
    rows = (Meeting.objects.exclude(status=Meeting.DRAFT)  # drafts are private to their creator
            .filter(starts_at__gte=period.start, starts_at__lt=period.end))
    if project:
        rows = rows.filter(project__name__icontains=project)
    if project_id:
        rows = rows.filter(project_id=project_id)
    by_status = dict(rows.order_by().values_list("status").annotate(n=Count("pk")))
    present = Count("attendees", filter=Q(attendees__active=True, attendees__attendance=MeetingAttendee.PRESENT))
    invited = Count("attendees", filter=Q(attendees__active=True))
    page = (rows.select_related("project").annotate(invited=invited, present=present).order_by("-starts_at", "id")
            [max(offset, 0):max(offset, 0) + max(min(limit, MAX_LIMIT), 0)])
    open_res = dict(Resolution.objects.filter(meeting__in=[m.pk for m in page], active=True, status=Resolution.OPEN)
                    .order_by().values_list("meeting_id").annotate(n=Count("pk")))
    return {**period.header(), "total": sum(by_status.values()), "by_status": by_status,
            "meetings": [{"id": str(m.id), "title": m.title, "kind": m.kind, "status": m.status,
                          "starts_at": m.starts_at, "project_id": str(m.project_id) if m.project_id else None,
                          "project_name": m.project.name if m.project_id else "", "invited": m.invited,
                          "present": m.present, "open_resolutions": open_res.get(m.id, 0)} for m in page]}
