"""`GET /monitor/overview`: desk charts per period. One block per enabled module, each `{totals, series}`; the series
are daily points summed into day/week/month buckets (Gregorian or Jalali months)."""
from accounts.models import User
from workspace import registry

from . import stats_other, stats_work
from .period import Period, bucketize

BLOCKS = {"tasks": stats_work.tasks, "projects": stats_work.projects, "letters": stats_work.letters,
          "meetings": stats_work.meetings, "crm": stats_other.crm, "chat": stats_other.chat}


def build(user: User, period: Period, bucket: str, calendar: str) -> dict:
    enabled = registry.enabled_modules()
    blocks = {}
    for code, fn in BLOCKS.items():
        if code not in enabled:
            continue
        data = fn(user, period.start, period.end)
        blocks[code] = {"totals": data["totals"],
                        "series": {k: bucketize(v, bucket, calendar) for k, v in data["series"].items()}}
    return {**period.header(), "bucket": bucket, "calendar": calendar, "modules": blocks}
