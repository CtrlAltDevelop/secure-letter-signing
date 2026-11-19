import pytest
from django.db import connection

TABLES = ["tasks_removalrequest", "tasks_tasktemplate", "workspace_mention", "accounts_orgtitle", "tasks_task",
          "projects_project", "accounts_user"]


@pytest.mark.skipif(connection.vendor != "sqlite", reason="reads the SQLite trigger catalogue")
@pytest.mark.parametrize("table", TABLES)
def test_delete_triggers_exist(db, table):
    """New tables are guarded, and tables SQLite rebuilt in these migrations got their triggers back."""
    with connection.cursor() as cursor:
        cursor.execute("SELECT name FROM sqlite_master WHERE type = 'trigger'")
        names = {row[0] for row in cursor.fetchall()}
    assert f"no_delete_{table}" in names
