"""`manage.py load_holidays --from-year 1405 --to-year 1410`: seed the fixed Jalali official holidays (idempotent)."""
from django.core.management.base import BaseCommand, CommandError

from workspace import holidays


class Command(BaseCommand):
    help = "Seed fixed Jalali official holidays for a range of Jalali years; lunar holidays are entered by the manager."

    def add_arguments(self, parser) -> None:
        parser.add_argument("--from-year", type=int, required=True)
        parser.add_argument("--to-year", type=int, required=True)

    def handle(self, *args, **options) -> None:
        try:
            created = holidays.seed_fixed(options["from_year"], options["to_year"])
        except ValueError as exc:
            raise CommandError(str(exc)) from exc
        self.stdout.write(f"created {created} holiday(s)")
