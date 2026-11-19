"""`manage.py run_daily`: once-a-day jobs (birthday notifications); safe to run repeatedly, one run per Tehran day."""
from django.core.management.base import BaseCommand

from accounts import daily


class Command(BaseCommand):
    help = "Run the daily jobs that have not run yet today (Asia/Tehran)."

    def handle(self, *args, **options) -> None:
        done = daily.run_pending()
        self.stdout.write(", ".join(f"{name}: {count}" for name, count in done.items()) or "nothing to do")
