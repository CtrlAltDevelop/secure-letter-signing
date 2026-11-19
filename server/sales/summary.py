"""Pipeline numbers over the leads the caller can see.

Open pipeline = open leads; weighted pipeline = sum(value * probability / 100) over open leads (floored once on the
sum). Probability buckets count open leads only.
"""
from collections import defaultdict
from typing import Any

from django.db.models import BigIntegerField, Count, F, QuerySet, Sum

from accounts.models import User
from workspace import periods
from workspace.schemas import user_ref

from . import queries
from .models import Lead

WEIGHT = Sum(F("value") * F("probability"), output_field=BigIntegerField())


def _stats(rows: QuerySet[Lead]) -> dict[str, int]:
    agg = rows.aggregate(n=Count("pk"), total=Sum("value"), weight=WEIGHT)
    return {"count": agg["n"], "value": agg["total"] or 0, "weighted": (agg["weight"] or 0) // 100}


def _simple(rows: QuerySet[Lead]) -> dict[str, int]:
    stats = _stats(rows)
    return {"count": stats["count"], "value": stats["value"]}


def _probability(open_rows: QuerySet[Lead]) -> list[dict[str, Any]]:
    out = []
    for name, low, high in queries.BUCKETS:
        stats = _stats(open_rows.filter(probability__gte=low, probability__lte=high))
        out.append({"bucket": name, "min": low, "max": high, **stats})
    return out


def _won_by_month(won: QuerySet[Lead]) -> list[dict[str, Any]]:
    sums: dict[periods.Key, list[int]] = defaultdict(lambda: [0, 0])
    for closed, value in won.exclude(closed_at=None).values_list("closed_at", "value"):
        key = periods.key_of(closed.date(), periods.JALALI, "month")
        sums[key][0] += 1
        sums[key][1] += value
    return [{"period": periods.label(k), "start": periods.bounds(k, periods.JALALI)[0],
             **periods.jalali_fields(k, periods.JALALI), "count": c, "value": v}
            for k, (c, v) in sorted(sums.items())]


def _by_owner(rows: QuerySet[Lead]) -> list[dict[str, Any]]:
    out = []
    for owner in User.objects.filter(pk__in=rows.values("owner_id")).order_by("full_name", "id"):
        mine = rows.filter(owner=owner)
        out.append({"owner": user_ref(owner), "open": _stats(mine.filter(status=Lead.OPEN)),
                    "won": _simple(mine.filter(status=Lead.WON)), "lost": _simple(mine.filter(status=Lead.LOST))})
    return out


def summarize(rows: QuerySet[Lead]) -> dict[str, Any]:
    open_rows, won = rows.filter(status=Lead.OPEN), rows.filter(status=Lead.WON)
    return {
        "won": _simple(won), "open": _stats(open_rows), "lost": _simple(rows.filter(status=Lead.LOST)),
        "by_status": {s: rows.filter(status=s).count() for s in (Lead.OPEN, Lead.WON, Lead.LOST)},
        "by_probability": _probability(open_rows), "won_by_month": _won_by_month(won), "by_owner": _by_owner(rows),
    }
