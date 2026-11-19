"""`GET /monitor/me`: my own numbers (every user). Blocks of modules that are switched off are omitted."""
from django.db.models import Count, Exists, OuterRef, Q
from django.utils import timezone

from accounts.models import User
from chat import unread
from letters.models import Letter, Participant, Referral
from meetings.models import Meeting, MeetingAttendee
from tasks.models import Task
from workspace import registry
from workspace.models import Reminder

from .period import Period, today_bounds


def _tasks(user: User, period: Period) -> dict:
    now = timezone.now()
    mine = Task.objects.filter(hidden=False, people__user=user, people__role="owner", people__active=True)
    active = Q(status__in=(Task.OPEN, Task.AWAITING))
    done = Q(status=Task.DONE, completed_at__gte=period.start, completed_at__lt=period.end)
    agg = mine.aggregate(open=Count("pk", filter=active), overdue=Count("pk", filter=active & Q(due_at__lt=now)),
                         done_in_period=Count("pk", filter=done))
    return agg


def _letters(user: User) -> dict:
    earlier = Participant.objects.filter(letter=OuterRef("letter"), role=Participant.SIGNER, decision="").filter(
        Q(position__lt=OuterRef("position")) | Q(position=OuterRef("position"), id__lt=OuterRef("id")))
    to_sign = (Participant.objects.filter(user=user, role=Participant.SIGNER, decision="",
                                          letter__status=Letter.IN_SIGNING)
               .filter(Q(letter__order="parallel") | ~Exists(earlier)).count())
    referred = Referral.objects.filter(to_user=user, status=Referral.PENDING).count()
    return {"to_sign": to_sign, "referred": referred, "waiting": to_sign + referred}


def _meetings_today(user: User) -> int:
    start, end = today_bounds()
    return MeetingAttendee.objects.filter(
        user=user, active=True, meeting__status__in=(Meeting.SCHEDULED, Meeting.HELD),
        meeting__starts_at__gte=start, meeting__starts_at__lt=end).count()


def _unread_chat(user: User) -> int:
    return sum(c.unread for c in unread.counts_for(user).values() if not c.muted)


def build(user: User, period: Period) -> dict:
    enabled = registry.enabled_modules()
    out: dict = period.header()
    if "tasks" in enabled:
        out["tasks"] = _tasks(user, period)
    if "letters" in enabled:
        out["letters"] = _letters(user)
    if "meetings" in enabled:
        out["meetings_today"] = _meetings_today(user)
    if "chat" in enabled:
        out["unread_chat"] = _unread_chat(user)
    start, end = today_bounds()
    out["reminders_today"] = Reminder.objects.filter(user=user, active=True, next_at__gte=start,
                                                     next_at__lt=end).count()
    return out
