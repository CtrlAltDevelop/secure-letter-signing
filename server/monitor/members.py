"""`GET /monitor/members` (per-person performance) and `GET /monitor/online` (last activity from live sessions)."""
from datetime import datetime, timedelta

from django.db.models import Avg, Count, DurationField, ExpressionWrapper, F, Max, Q
from django.utils import timezone

from accounts.models import Session, User
from chat.models import Message
from letters.models import Signature
from meetings.models import MeetingAttendee
from tasks.models import Task, TaskPerson
from workspace import registry
from workspace.schemas import user_ref

from .period import Period

ONLINE_WINDOW = timedelta(minutes=5)
MAX_USERS = 500
SORTS = ("done", "overdue", "activity")
HISTORY_LIMIT = 50


def _task_rows(period: Period, now: datetime) -> dict[int, dict]:
    done = Q(task__status=Task.DONE, task__completed_at__gte=period.start, task__completed_at__lt=period.end)
    on_time = done & (Q(task__due_at__isnull=True) | Q(task__completed_at__lte=F("task__due_at")))
    late = done & Q(task__due_at__isnull=False, task__completed_at__gt=F("task__due_at"))
    active = Q(task__status__in=(Task.OPEN, Task.AWAITING))
    delay = ExpressionWrapper(F("task__completed_at") - F("task__due_at"), output_field=DurationField())
    rows = (TaskPerson.objects.filter(role=TaskPerson.OWNER, active=True, task__hidden=False).order_by()
            .values("user_id")
            .annotate(on_time=Count("pk", filter=on_time), late=Count("pk", filter=late),
                      overdue=Count("pk", filter=active & Q(task__due_at__lt=now)),
                      avg_delay=Avg(delay, filter=late)))
    return {r["user_id"]: r for r in rows}


def _counts(rows) -> dict[int, int]:
    return {row[0]: row[1] for row in rows}


def _activity(enabled: set[str], period: Period) -> dict[str, dict[int, int]]:
    out: dict[str, dict[int, int]] = {}
    if "chat" in enabled:
        out["messages"] = _counts(Message.objects.filter(deleted=False, created_at__gte=period.start,
                                                         created_at__lt=period.end).order_by()
                                  .values_list("author_id").annotate(n=Count("pk")))
    if "letters" in enabled:
        out["letters_signed"] = _counts(Signature.objects.filter(
            decision="approved", created_at__gte=period.start, created_at__lt=period.end).order_by()
            .values_list("signer_id").annotate(n=Count("pk")))
    if "meetings" in enabled:
        out["meetings_attended"] = _counts(MeetingAttendee.objects.filter(
            active=True, user__isnull=False, attendance=MeetingAttendee.PRESENT, meeting__starts_at__gte=period.start,
            meeting__starts_at__lt=period.end).order_by().values_list("user_id").annotate(n=Count("pk")))
    return out


def _person(user: User, tasks: dict | None, activity: dict[str, dict[int, int]]) -> dict:
    out: dict = {"user": user_ref(user).model_dump()}
    if tasks is not None:
        delay = tasks["avg_delay"]
        out["tasks"] = {"on_time": tasks["on_time"], "late": tasks["late"], "overdue": tasks["overdue"],
                        "avg_delay_days": round(delay.total_seconds() / 86400, 2) if delay else 0}
    for key, counts in activity.items():
        out[key] = counts.get(user.id, 0)
    return out


def _score(row: dict, sort: str) -> tuple:
    tasks = row.get("tasks", {"on_time": 0, "late": 0, "overdue": 0})
    if sort == "done":
        return (tasks["on_time"] + tasks["late"], tasks["on_time"])
    if sort == "overdue":
        return (tasks["overdue"], tasks["late"])
    extra = sum(v for k, v in row.items() if k in ("messages", "letters_signed", "meetings_attended"))
    return (extra + tasks["on_time"] + tasks["late"],)


def performance(period: Period, sort: str, limit: int, offset: int) -> dict:
    enabled = registry.enabled_modules()
    users = list(User.objects.filter(is_active=True).select_related("org_title").order_by("id")[:MAX_USERS])
    tasks = _task_rows(period, timezone.now()) if "tasks" in enabled else None
    activity = _activity(enabled, period)
    empty = {"on_time": 0, "late": 0, "overdue": 0, "avg_delay": None}
    rows = [_person(u, (tasks.get(u.id, empty) if tasks is not None else None), activity) for u in users]
    rows.sort(key=lambda r: (_score(r, sort), -r["user"]["id"]), reverse=True)
    start = max(offset, 0)
    return {**period.header(), "sort": sort, "total": len(rows), "members": rows[start:start + max(limit, 0)]}


def _online_row(user: User, last_active: datetime | None, now: datetime) -> dict:
    online = last_active is not None and now - last_active <= ONLINE_WINDOW
    return {"user": user_ref(user).model_dump(), "last_active": last_active, "online": online}


def online(history_of: int | None) -> dict:
    now = timezone.now()
    live = Max("sessions__last_active", filter=Q(sessions__revoked_at__isnull=True))
    users = (User.objects.filter(is_active=True).select_related("org_title").annotate(seen=live).order_by("id")[:MAX_USERS])
    rows = [_online_row(u, u.seen, now) for u in users]
    rows.sort(key=lambda r: (r["online"], r["last_active"] is not None, r["last_active"] or now), reverse=True)
    out: dict = {"now": now, "window_seconds": int(ONLINE_WINDOW.total_seconds()), "users": rows}
    if history_of is not None:
        sessions = (Session.objects.filter(user_id=history_of).order_by("-last_active")[:HISTORY_LIMIT])
        out["history"] = [{"device_name": s.device_name, "platform": s.platform, "created_at": s.created_at,
                           "last_active": s.last_active, "revoked": s.revoked_at is not None} for s in sessions]
    return out
