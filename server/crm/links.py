"""What is linked to a customer file, as seen by the caller: tasks, meetings and letters."""
from accounts.models import User
from workspace import registry

from .models import Customer


def _page(rows, limit: int, offset: int) -> list:
    start = max(offset, 0)
    return list(rows[start : start + max(min(limit, 200), 0)])


def _enabled(code: str) -> bool:
    return code in registry.enabled_modules()


def tasks_of(user: User, customer: Customer, limit: int, offset: int) -> list:
    from tasks.queries import visible_tasks
    from tasks.serializers import briefs

    if not _enabled("tasks"):
        return []
    rows = visible_tasks(user).filter(customer=customer).select_related("creator").order_by("-updated_at", "id")
    return briefs(user, _page(rows, limit, offset))


def meetings_of(user: User, customer: Customer, limit: int, offset: int) -> list:
    from meetings.rules import visible_meetings
    from meetings.serializers import briefs

    if not _enabled("meetings"):
        return []
    rows = visible_meetings(user).filter(customer=customer).select_related("subject").order_by(
        "-starts_at", "-created_at")
    return briefs(user, _page(rows, limit, offset))


def letters_of(user: User, customer: Customer, limit: int, offset: int) -> list:
    from letters.briefs import briefs
    from letters.models import CustomerLink
    from letters.rules import visible_letters

    if not _enabled("letters"):
        return []
    subjects = CustomerLink.objects.filter(customer_ref=customer.id, active=True).values("subject_id")
    rows = visible_letters(user).filter(subject_id__in=subjects).order_by("-created_at", "id")
    return briefs(user, _page(rows, limit, offset))
