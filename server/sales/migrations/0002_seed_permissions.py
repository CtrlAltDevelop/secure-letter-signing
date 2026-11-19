"""Permission `sales.manage`: granted to nobody; the company manager grants it in the permission admin."""
from django.db import migrations


def seed(apps, schema_editor) -> None:
    Permission = apps.get_model("accounts", "Permission")
    Permission.objects.get_or_create(code="sales.manage", defaults={"description": "Manage sales leads and the pipeline"})


class Migration(migrations.Migration):
    dependencies = [
        ("sales", "0001_initial"),
        ("accounts", "0010_signing_pin_and_session_biometric"),
    ]
    operations = [migrations.RunPython(seed, migrations.RunPython.noop)]
