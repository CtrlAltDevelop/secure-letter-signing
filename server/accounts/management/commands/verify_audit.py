from django.core.management.base import BaseCommand, CommandError

from accounts.models import AuditEvent, verify_audit_chain


class Command(BaseCommand):
    help = "Verify the hash chain of the audit log (exit code 1 if a row was altered or removed)."

    def add_arguments(self, parser):
        parser.add_argument("--expect-head", metavar="HASH", help="head hash recorded earlier (from `head:` output); fails if the chain no longer contains it")

    def handle(self, *args, **options):
        broken = verify_audit_chain()
        if broken is not None:
            raise CommandError(f"Audit chain broken at event #{broken}")
        expected = options.get("expect_head")
        if expected and not AuditEvent.objects.filter(hash=expected).exists():
            raise CommandError("Expected head hash not found: tail rows were deleted or the chain was rewritten")
        head = AuditEvent.objects.exclude(hash="").order_by("-id").values_list("id", "hash").first()
        self.stdout.write(self.style.SUCCESS(f"Audit chain intact ({AuditEvent.objects.count()} events)."))
        if head:  # record this somewhere outside the database: it is the only way to notice deleted tail rows
            self.stdout.write(f"head: #{head[0]} {head[1]}")
