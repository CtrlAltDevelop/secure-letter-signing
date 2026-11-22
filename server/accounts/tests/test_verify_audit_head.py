import pytest
from django.core.management import call_command
from django.core.management.base import CommandError

from accounts.models import AuditEvent


def test_expect_head_fails_when_tail_rows_are_gone(db, make_user):
    user = make_user("a@x.com")
    from accounts.models import audit
    audit(user, "x", "1")
    head = AuditEvent.objects.exclude(hash="").order_by("-id").first().hash
    call_command("verify_audit", expect_head=head)
    with pytest.raises(CommandError):
        call_command("verify_audit", expect_head="0" * 64)
