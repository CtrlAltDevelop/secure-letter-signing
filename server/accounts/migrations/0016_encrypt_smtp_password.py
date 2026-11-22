from django.db import migrations

import core.fields
from core import cryptoutil


def encrypt_existing(apps, schema_editor):
    """Rows hold plaintext until now; rewrite through raw SQL so the field does not try to decrypt them."""
    with schema_editor.connection.cursor() as cur:
        cur.execute("SELECT id, smtp_password FROM accounts_companysettings WHERE smtp_password <> ''")
        for pk, plain in cur.fetchall():
            token = cryptoutil.encrypt_bytes(plain.encode()).decode()
            cur.execute("UPDATE accounts_companysettings SET smtp_password = %s WHERE id = %s", [token, pk])


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0015_invite_guest"),
    ]

    operations = [
        migrations.AlterField(
            model_name="companysettings",
            name="smtp_password",
            field=core.fields.EncryptedTextField(blank=True),
        ),
        migrations.RunPython(encrypt_existing, migrations.RunPython.noop),
    ]
