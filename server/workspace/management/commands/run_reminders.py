"""`manage.py run_reminders [--once]`: fire due reminders every 30 s (dev; production uses a scheduler)."""
import logging
import time

from django.core.management.base import BaseCommand

from accounts.daily import run_pending
from workspace.reminders import fire_due_reminders

logger = logging.getLogger(__name__)
INTERVAL_SECONDS = 30


class Command(BaseCommand):
    help = "Fire due reminders; loops every 30 seconds unless --once."

    def add_arguments(self, parser) -> None:
        parser.add_argument("--once", action="store_true", help="run one tick and exit")

    def handle(self, *args, **options) -> None:
        while True:
            try:
                fired = fire_due_reminders()
                if fired:
                    self.stdout.write(f"fired {fired} reminder(s)")
                for name, count in run_pending().items():  # once per Tehran day, after midnight
                    self.stdout.write(f"daily {name}: {count}")
            except Exception:  # noqa: BLE001  one bad tick must not stop the loop
                logger.exception("Reminder tick failed")
                if options["once"]:
                    raise
            if options["once"]:
                return
            time.sleep(INTERVAL_SECONDS)
