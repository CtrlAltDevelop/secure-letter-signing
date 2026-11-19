"""Work calendar: the items one user may see in a time range (tasks, meetings, own reminders, project dates).

Every query starts from the module's own visibility helper, so the calendar never shows more than the lists do.
Item shape: {kind, id, subject_id, title, start, end, all_day, status, project_id, project_name, color, done}.
`all_day` project items end at the start of the day after the last day (exclusive).
"""
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta, timezone as dt_timezone
from uuid import UUID

from django.db.models import Q, QuerySet
from ninja.errors import HttpError

from accounts.models import User

from . import registry
from .models import Label, Reminder, SubjectLabel
from .recurrence import TEHRAN

MAX_DAYS = 100
KINDS = ("task", "meeting", "reminder", "project")
REMINDER_CAP = 500
ITEM_CAP = 2000


@dataclass(frozen=True)
class Query:
    start: datetime
    end: datetime
    kinds: frozenset[str]
    project: UUID | None = None
    customer: UUID | None = None
    label: int | None = None
    owner: int | None = None


def utc(value: datetime) -> datetime:
    return (value.replace(tzinfo=dt_timezone.utc) if value.tzinfo is None else value).astimezone(dt_timezone.utc)


def check_range(start: datetime, end: datetime) -> tuple[datetime, datetime]:
    start, end = utc(start), utc(end)
    if end <= start:
        raise HttpError(422, "to must be after from")
    if end - start > timedelta(days=MAX_DAYS):
        raise HttpError(422, f"The range is limited to {MAX_DAYS} days")
    return start, end


def parse_kinds(raw: str) -> frozenset[str]:
    wanted = {k.strip() for k in raw.split(",") if k.strip()}
    if not wanted:
        return frozenset(KINDS)
    if not wanted <= set(KINDS):
        raise HttpError(422, f"kinds must be among {', '.join(KINDS)}")
    return frozenset(wanted)


def day_start(day: date) -> datetime:
    return datetime.combine(day, time.min, tzinfo=TEHRAN).astimezone(dt_timezone.utc)


def tehran_days(start: datetime, end: datetime) -> tuple[date, date]:
    return start.astimezone(TEHRAN).date(), end.astimezone(TEHRAN).date()


def _item(kind: str, obj_id, subject_id, title: str, start: datetime, end: datetime, **extra) -> dict:
    base = {"kind": kind, "id": str(obj_id), "subject_id": str(subject_id) if subject_id else None, "title": title,
            "start": utc(start), "end": utc(end), "all_day": False, "status": "", "project_id": None,
            "project_name": "", "color": 0, "done": False}
    return {**base, **extra}


def _label_subjects(user: User, label_id: int) -> QuerySet:
    ok = Label.objects.filter(pk=label_id, active=True).filter(Q(scope=Label.ORG) | Q(owner=user)).exists()
    rows = SubjectLabel.objects.filter(label_id=label_id, active=True) if ok else SubjectLabel.objects.none()
    return rows.values("subject_id")


def task_items(rows: QuerySet, q: Query, user: User, *, with_owners: bool = False) -> list[dict]:
    """`rows`: the tasks the caller may see (or the monitored set). Filters and range are applied here."""
    from tasks.models import Task, TaskPerson

    rows = rows.filter(hidden=False).exclude(status=Task.CANCELLED).filter(
        Q(start_at__gte=q.start, start_at__lt=q.end) | Q(due_at__gte=q.start, due_at__lt=q.end)
        | Q(start_at__lt=q.start, due_at__gte=q.end))
    if q.project:
        rows = rows.filter(project_id=q.project)
    if q.customer:
        rows = rows.filter(customer_id=q.customer)
    if q.label is not None:
        rows = rows.filter(subject_id__in=_label_subjects(user, q.label))
    if q.owner is not None:
        mine = TaskPerson.objects.filter(user_id=q.owner, role=TaskPerson.OWNER, active=True).values("task_id")
        rows = rows.filter(pk__in=mine)
    tasks = list(rows.select_related("project").order_by("due_at", "start_at", "id")[:ITEM_CAP])
    owners: dict = {}
    if with_owners:
        for tid, uid in TaskPerson.objects.filter(task__in=tasks, role=TaskPerson.OWNER, active=True).values_list(
                "task_id", "user_id"):
            owners.setdefault(tid, []).append(uid)
    out = []
    for t in tasks:
        start, end = t.start_at or t.due_at, t.due_at or t.start_at
        extra = {"owner_ids": sorted(owners.get(t.id, []))} if with_owners else {}
        out.append(_item("task", t.id, t.subject_id, t.title, start, end, all_day=t.all_day, status=t.status,
                         project_id=str(t.project_id) if t.project_id else None,
                         project_name=t.project.name if t.project_id else "",
                         color=t.project.color if t.project_id else 0, done=t.status == Task.DONE, **extra))
    return out


def _meeting_items(user: User, q: Query) -> list[dict]:
    from meetings.models import Meeting
    from meetings.rules import visible_meetings

    rows = visible_meetings(user).exclude(status=Meeting.CANCELLED).filter(starts_at__gte=q.start,
                                                                        starts_at__lt=q.end)
    if q.project:
        rows = rows.filter(project_id=q.project)
    if q.customer:
        rows = rows.filter(customer_id=q.customer)
    if q.label is not None:
        rows = rows.filter(subject_id__in=_label_subjects(user, q.label))
    if q.owner is not None:
        rows = rows.filter(creator_id=q.owner)
    out = []
    for m in rows.select_related("project").order_by("starts_at", "id")[:ITEM_CAP]:
        out.append(_item("meeting", m.id, m.subject_id, m.title, m.starts_at, m.ends_at or m.starts_at,
                         status=m.status, project_id=str(m.project_id) if m.project_id else None,
                         project_name=m.project.name if m.project_id else "",
                         color=m.project.color if m.project_id else 0,
                         done=m.status in (Meeting.HELD, Meeting.CLOSED)))
    return out


def _in_project(obj, project: UUID) -> bool:
    return getattr(obj, "project_id", None) == project or getattr(obj, "pk", None) == project


def _reminder_items(user: User, q: Query) -> list[dict]:
    if q.customer or q.owner is not None:
        return []
    rows = Reminder.objects.filter(user=user, active=True, next_at__gte=q.start, next_at__lt=q.end)
    if q.label is not None:
        rows = rows.filter(subject_id__in=_label_subjects(user, q.label))
    enabled = registry.enabled_modules()
    out = []
    for r in rows.select_related("subject").order_by("next_at", "id")[:REMINDER_CAP]:
        spec = registry.get(r.subject.module)
        obj = spec.resolve(r.subject) if spec and r.subject.module in enabled else None
        if obj is None or not spec.can(user, obj, "see"):
            continue
        if q.project and not _in_project(obj, q.project):
            continue
        out.append(_item("reminder", r.id, r.subject_id, spec.title(obj) if spec.title else "", r.next_at, r.next_at))
    return out


def _project_items(user: User, q: Query) -> list[dict]:
    from projects.models import Project, ProjectMember

    if q.customer or q.label is not None:
        return []
    first, last = tehran_days(q.start, q.end)
    mine = ProjectMember.objects.filter(user=user, active=True).values("project_id")
    rows = Project.objects.filter(pk__in=mine).exclude(status=Project.ARCHIVED).filter(
        Q(start_date__gte=first, start_date__lte=last) | Q(end_date__gte=first, end_date__lte=last)
        | Q(start_date__lt=first, end_date__gt=last))
    if q.project:
        rows = rows.filter(pk=q.project)
    if q.owner is not None:
        rows = rows.filter(owner_id=q.owner)
    out = []
    for p in rows.order_by("start_date", "id")[:ITEM_CAP]:
        begin, finish = p.start_date or p.end_date, p.end_date or p.start_date
        out.append(_item("project", p.id, p.subject_id, p.name, day_start(begin), day_start(finish + timedelta(days=1)),
                         all_day=True, status=p.status, project_id=str(p.id), project_name=p.name, color=p.color,
                         done=p.status == Project.DONE))
    return out


def items_for(user: User, q: Query) -> list[dict]:
    from tasks.queries import visible_tasks

    enabled = registry.enabled_modules()
    out: list[dict] = []
    if "task" in q.kinds and "tasks" in enabled:
        out += task_items(visible_tasks(user), q, user)
    if "meeting" in q.kinds and "meetings" in enabled:
        out += _meeting_items(user, q)
    if "reminder" in q.kinds:
        out += _reminder_items(user, q)
    if "project" in q.kinds and "projects" in enabled:
        out += _project_items(user, q)
    return sorted(out, key=lambda i: (i["start"], i["kind"], i["id"]))
