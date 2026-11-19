"""Permission `monitor.view`: read-only overview of colleagues' active tasks. Granted to nobody (the manager grants it)."""
from django.db import migrations


def seed(apps, schema_editor):
    Permission = apps.get_model("accounts", "Permission")
    Permission.objects.get_or_create(code="monitor.view", defaults={"description": "Overview of colleagues' tasks"})


class Migration(migrations.Migration):
    dependencies = [("workspace", "0005_holiday_bookmark_pin"), ("accounts", "0012_org_titles_status")]
    operations = [migrations.RunPython(seed, migrations.RunPython.noop)]
