"""Permissions `task.create` and `project.create`, granted to every existing user (new users get them at signup)."""
from django.db import migrations

CATALOG = [
    ("task.create", "Create tasks"),
    ("project.create", "Create projects"),
]


def seed(apps, schema_editor):
    Permission = apps.get_model("accounts", "Permission")
    User = apps.get_model("accounts", "User")
    perms = [Permission.objects.get_or_create(code=code, defaults={"description": text})[0] for code, text in CATALOG]
    for user in User.objects.all():
        user.grants.add(*perms)


class Migration(migrations.Migration):
    dependencies = [
        ("workspace", "0002_no_delete_triggers"),
        ("accounts", "0010_signing_pin_and_session_biometric"),
    ]
    operations = [migrations.RunPython(seed, migrations.RunPython.noop)]
