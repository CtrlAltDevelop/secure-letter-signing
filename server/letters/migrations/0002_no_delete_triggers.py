"""Nothing is ever deleted: the database itself refuses DELETE (and UPDATE on immutable evidence tables)."""
from django.db import migrations

NO_DELETE = [
    "accounts_user", "accounts_session", "accounts_auditevent", "accounts_notification", "accounts_invitecode",
    "keys_userkey", "keys_companykeyversion", "keys_companykeywrap",
    "letters_letter", "letters_participant", "letters_dockeywrap", "letters_signature",
    "letters_attachment", "letters_letterevent",
]
NO_UPDATE = ["accounts_auditevent", "letters_signature", "letters_letterevent"]
MESSAGE = "deleting or rewriting this record is not allowed"


def _statements(vendor: str, verb: str, table: str) -> tuple[list[str], list[str]]:
    name = f"no_{verb.lower()}_{table}"
    if vendor == "sqlite":
        create = (f"CREATE TRIGGER {name} BEFORE {verb} ON {table} "
                  f"BEGIN SELECT RAISE(ABORT, '{MESSAGE}'); END")
        return [create], [f"DROP TRIGGER IF EXISTS {name}"]
    func = f"{name}_fn"
    return (
        [f"CREATE FUNCTION {func}() RETURNS trigger AS $$ BEGIN RAISE EXCEPTION '{MESSAGE}'; END; $$ LANGUAGE plpgsql",
         f"CREATE TRIGGER {name} BEFORE {verb} ON {table} FOR EACH ROW EXECUTE FUNCTION {func}()"],
        [f"DROP TRIGGER IF EXISTS {name} ON {table}", f"DROP FUNCTION IF EXISTS {func}()"],
    )


def _apply(schema_editor, reverse: bool) -> None:
    vendor = schema_editor.connection.vendor
    if vendor not in ("sqlite", "postgresql"):
        raise NotImplementedError(f"no-delete triggers are not implemented for {vendor}")
    pairs = [("DELETE", t) for t in NO_DELETE] + [("UPDATE", t) for t in NO_UPDATE]
    for verb, table in pairs:
        up, down = _statements(vendor, verb, table)
        for sql in down if reverse else up:
            schema_editor.execute(sql)


def forwards(apps, schema_editor):
    _apply(schema_editor, reverse=False)


def backwards(apps, schema_editor):
    _apply(schema_editor, reverse=True)


class Migration(migrations.Migration):
    dependencies = [("letters", "0001_initial"), ("accounts", "0005_notification_auditevent_hash_auditevent_prev_hash_and_more"), ("keys", "0001_initial")]
    operations = [migrations.RunPython(forwards, backwards)]
