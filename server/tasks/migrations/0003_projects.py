"""`project_id` / `column_id` become real nullable foreign keys (existing rows are all null)."""
import django.db.models.deletion
from django.db import migrations, models

from core import dbguards


def reguard(apps, schema_editor) -> None:
    """SQLite rebuilds tasks_task for the new foreign keys and drops its trigger: drop (if any) and recreate it."""
    tables = ["tasks_task"]
    dbguards.apply_guards(schema_editor, tables, reverse=True)
    dbguards.apply_guards(schema_editor, tables)


class Migration(migrations.Migration):

    dependencies = [
        ('projects', '0002_no_delete_triggers'),
        ('tasks', '0002_no_delete_triggers'),
    ]

    operations = [
        migrations.RemoveField(model_name='task', name='column_id'),
        migrations.RemoveField(model_name='task', name='project_id'),
        migrations.AddField(
            model_name='task',
            name='column',
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.PROTECT, related_name='tasks', to='projects.boardcolumn'),
        ),
        migrations.AddField(
            model_name='task',
            name='project',
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.PROTECT, related_name='tasks', to='projects.project'),
        ),
        migrations.RunPython(reguard, migrations.RunPython.noop),
    ]
