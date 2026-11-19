"""`monitor.view` oversight: read-only briefs (titles, status, dates, owners) of colleagues' active tasks.

The one deliberate exception to "the manager sees nothing automatically": a holder never gets descriptions, comments,
files, chat or letter bodies, and the task detail endpoints keep their normal rules.
"""
from django.db.models import QuerySet
from ninja.errors import HttpError

from accounts.models import User

PERMISSION = "monitor.view"


def require_holder(user: User) -> None:
    if not user.has_grant(PERMISSION):
        raise HttpError(403, "Permission denied")


def active_tasks() -> QuerySet:
    from tasks.models import Task

    return Task.objects.filter(status__in=(Task.OPEN, Task.AWAITING), hidden=False)
