from django.db import connection

from accounts.models import CompanySettings


def test_smtp_password_is_encrypted_at_rest(db):
    cs = CompanySettings.load()
    cs.smtp_password = "s3cret-pass"
    cs.save()
    with connection.cursor() as cur:
        cur.execute("SELECT smtp_password FROM accounts_companysettings WHERE id = %s", [cs.pk])
        raw = cur.fetchone()[0]
    assert raw and "s3cret-pass" not in raw
    assert CompanySettings.load().smtp_password == "s3cret-pass"
