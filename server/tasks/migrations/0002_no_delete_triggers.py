"""Nothing is deleted: the database refuses DELETE on every tasks table (rows may be updated)."""
from django.db import migrations

from core import dbguards


class Migration(migrations.Migration):
    dependencies = [("tasks", "0001_initial")]
    operations = [dbguards.guard(["tasks_task", "tasks_taskperson", "tasks_checklistitem"])]
