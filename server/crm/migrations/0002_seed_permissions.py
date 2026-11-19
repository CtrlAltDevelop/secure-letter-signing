"""Permissions `customer.create` (granted to every existing user, like `task.create`) and `customer.import`
(granted to nobody: the manager grants it)."""
from django.db import migrations


def seed(apps, schema_editor) -> None:
    Permission = apps.get_model("accounts", "Permission")
    User = apps.get_model("accounts", "User")
    create, _ = Permission.objects.get_or_create(code="customer.create", defaults={"description": "Create customer files"})
    Permission.objects.get_or_create(code="customer.import", defaults={"description": "Import customers from CSV/xlsx"})
    for user in User.objects.all():
        user.grants.add(create)


class Migration(migrations.Migration):
    dependencies = [
        ("crm", "0001_customer"),
        ("accounts", "0010_signing_pin_and_session_biometric"),
    ]
    operations = [migrations.RunPython(seed, migrations.RunPython.noop)]
