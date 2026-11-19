"""`ModuleSpec.stats` callbacks of crm, chat, finance and sales. Chat is message counts per day only (never text);
finance and sales contribute only for callers who hold their own permission, and only over what that permission
already lets them see."""
from datetime import datetime

from django.db.models import Count, Sum

from accounts.models import User
from chat.models import Message
from crm.models import Customer, CustomerEvent
from finance import reports, rules as finance_rules
from sales import rules as sales_rules
from sales.models import Lead

from .period import daily, from_bounds, total


def crm(user: User, start: datetime, end: datetime) -> dict:
    period = from_bounds(start, end)
    created = daily(Customer.objects.all(), "created_at", period)
    activity = daily(CustomerEvent.objects.all(), "at", period)
    by_status = dict(Customer.objects.order_by().values_list("status").annotate(n=Count("pk")))
    return {"totals": {"created": total(created), "events": total(activity), "all": sum(by_status.values()),
                       "by_status": by_status},
            "series": {"created": created, "activity": activity}}


def chat(user: User, start: datetime, end: datetime) -> dict:
    period = from_bounds(start, end)
    messages = daily(Message.objects.filter(deleted=False), "created_at", period)
    return {"totals": {"messages": total(messages)}, "series": {"messages": messages}}


def finance(user: User, start: datetime, end: datetime) -> dict:
    if not finance_rules.holds(user):
        return {}
    period = from_bounds(start, end)
    rows = finance_rules.visible_docs(user).filter(date__gte=period.first, date__lte=period.last)
    return {"totals": reports.totals(rows), "series": {}}


def sales(user: User, start: datetime, end: datetime) -> dict:
    if not sales_rules.holds(user):
        return {}
    period = from_bounds(start, end)
    rows = sales_rules.visible_leads(user).filter(created_at__gte=period.start, created_at__lt=period.end)
    by_status = {s: {"count": 0, "value": 0} for s in (Lead.OPEN, Lead.WON, Lead.LOST)}
    for status, count, value in rows.order_by().values_list("status").annotate(n=Count("pk"), v=Sum("value")):
        by_status[status] = {"count": count, "value": value or 0}
    created = daily(rows, "created_at", period)
    return {"totals": {"created": total(created), "by_status": by_status}, "series": {"created": created}}
