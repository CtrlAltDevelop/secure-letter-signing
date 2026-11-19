"""Append-only guards for new tables: the database itself refuses DELETE (and UPDATE on evidence tables).

Same trigger SQL as `letters/migrations/0002_no_delete_triggers.py` (kept untouched), packaged for new migrations:

    operations = [..., dbguards.guard(["app_table", ...], no_update=["app_evidence"])]
"""
from collections.abc import Iterable

from django.db import migrations

MESSAGE = "deleting or rewriting this record is not allowed"
SUPPORTED_VENDORS = ("sqlite", "postgresql")


def statements(vendor: str, verb: str, table: str) -> tuple[list[str], list[str]]:
    """(create, drop) SQL for one trigger that refuses `verb` ("DELETE" or "UPDATE") on `table`."""
    if vendor not in SUPPORTED_VENDORS:
        raise NotImplementedError(f"append-only triggers are not implemented for {vendor}")
    name = f"no_{verb.lower()}_{table}"
    if vendor == "sqlite":
        create = f"CREATE TRIGGER {name} BEFORE {verb} ON {table} BEGIN SELECT RAISE(ABORT, '{MESSAGE}'); END"
        return [create], [f"DROP TRIGGER IF EXISTS {name}"]
    func = f"{name}_fn"
    return (
        [f"CREATE FUNCTION {func}() RETURNS trigger AS $$ BEGIN RAISE EXCEPTION '{MESSAGE}'; END; $$ LANGUAGE plpgsql",
         f"CREATE TRIGGER {name} BEFORE {verb} ON {table} FOR EACH ROW EXECUTE FUNCTION {func}()"],
        [f"DROP TRIGGER IF EXISTS {name} ON {table}", f"DROP FUNCTION IF EXISTS {func}()"],
    )


def apply_guards(schema_editor, tables: Iterable[str], no_update: Iterable[str] = (), *, reverse: bool = False) -> None:
    vendor = schema_editor.connection.vendor
    pairs = [("DELETE", t) for t in tables] + [("UPDATE", t) for t in no_update]
    for verb, table in pairs:
        up, down = statements(vendor, verb, table)
        for sql in down if reverse else up:
            schema_editor.execute(sql)


def guard(tables: Iterable[str], no_update: Iterable[str] = ()) -> migrations.RunPython:
    """Migration operation: no DELETE on every table in `tables`, no UPDATE on every table in `no_update`."""
    tables, no_update = tuple(tables), tuple(no_update)

    def forwards(apps, schema_editor) -> None:
        apply_guards(schema_editor, tables, no_update)

    def backwards(apps, schema_editor) -> None:
        apply_guards(schema_editor, tables, no_update, reverse=True)

    return migrations.RunPython(forwards, backwards)
