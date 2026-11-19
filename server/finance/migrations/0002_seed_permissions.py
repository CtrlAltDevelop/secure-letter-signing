"""Permission `finance.manage`: granted to nobody; the company manager grants it in the permission admin."""
from django.db import migrations


def seed(apps, schema_editor) -> None:
    Permission = apps.get_model("accounts", "Permission")
    Permission.objects.get_or_create(code="finance.manage", defaults={"description": "Manage finance documents and reports"})


class Migration(migrations.Migration):
    dependencies = [
        ("finance", "0001_initial"),
        ("accounts", "0010_signing_pin_and_session_biometric"),
    ]
    operations = [migrations.RunPython(seed, migrations.RunPython.noop)]
