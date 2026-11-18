"""A sent letter's title and encrypted body cannot change at the database level either."""
from django.db import migrations

MSG = "a sent letter is immutable"


def forwards(apps, schema_editor):
    if schema_editor.connection.vendor == "sqlite":
        schema_editor.execute(
            "CREATE TRIGGER sent_letter_is_immutable BEFORE UPDATE OF title, body ON letters_letter "
            f"WHEN OLD.status <> 'draft' BEGIN SELECT RAISE(ABORT, '{MSG}'); END")
    else:
        schema_editor.execute(
            "CREATE FUNCTION sent_letter_is_immutable_fn() RETURNS trigger AS $$ BEGIN "
            "IF OLD.status <> 'draft' AND (NEW.title IS DISTINCT FROM OLD.title OR NEW.body::text IS DISTINCT FROM OLD.body::text) "
            f"THEN RAISE EXCEPTION '{MSG}'; END IF; RETURN NEW; END; $$ LANGUAGE plpgsql")
        schema_editor.execute(
            "CREATE TRIGGER sent_letter_is_immutable BEFORE UPDATE ON letters_letter "
            "FOR EACH ROW EXECUTE FUNCTION sent_letter_is_immutable_fn()")


def backwards(apps, schema_editor):
    if schema_editor.connection.vendor == "sqlite":
        schema_editor.execute("DROP TRIGGER IF EXISTS sent_letter_is_immutable")
    else:
        schema_editor.execute("DROP TRIGGER IF EXISTS sent_letter_is_immutable ON letters_letter")
        schema_editor.execute("DROP FUNCTION IF EXISTS sent_letter_is_immutable_fn()")


class Migration(migrations.Migration):
    dependencies = [("letters", "0002_no_delete_triggers")]
    operations = [migrations.RunPython(forwards, backwards)]
