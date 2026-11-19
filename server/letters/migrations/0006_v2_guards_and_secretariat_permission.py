"""Append-only guards for the new tables, trigger re-creation after the SQLite rebuild of letters_letter, and the
`letter.secretariat` permission (seeded, granted to nobody: the manager grants it in the permission admin)."""
from importlib import import_module

from django.db import migrations

from core import dbguards

NEW_TABLES = ["letters_referral", "letters_lettertasklink", "letters_archivemark", "letters_paraph",
              "letters_numbersequence", "letters_secretariatentry", "letters_customerlink"]
immutable = import_module("letters.migrations.0003_sent_letter_immutable")


def reguard_letter(apps, schema_editor) -> None:
    """SQLite rebuilt letters_letter for the new one-to-one and dropped its triggers: drop (if any) and recreate."""
    dbguards.apply_guards(schema_editor, ["letters_letter"], reverse=True)
    immutable.backwards(apps, schema_editor)
    dbguards.apply_guards(schema_editor, ["letters_letter"])
    immutable.forwards(apps, schema_editor)


def seed_permission(apps, schema_editor) -> None:
    apps.get_model("accounts", "Permission").objects.get_or_create(
        code="letter.secretariat", defaults={"description": "Register letter numbers (secretariat)"})


class Migration(migrations.Migration):
    dependencies = [("letters", "0005_letter_subjects"),
                    ("accounts", "0010_signing_pin_and_session_biometric")]
    operations = [
        migrations.RunPython(reguard_letter, migrations.RunPython.noop),
        dbguards.guard(NEW_TABLES, no_update=["letters_paraph"]),
        migrations.RunPython(seed_permission, migrations.RunPython.noop),
    ]
