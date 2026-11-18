from django.db import migrations

CATALOG = [
    ("user", "Base permission: log in and use the app"),
    ("letter.create", "Create letters"),
    ("letter.see", "See letters"),
    ("letter.sign", "Sign letters"),
]


def seed(apps, schema_editor):
    Permission = apps.get_model("accounts", "Permission")
    for code, description in CATALOG:
        Permission.objects.get_or_create(code=code, defaults={"description": description})


class Migration(migrations.Migration):
    dependencies = [("accounts", "0001_initial")]
    operations = [migrations.RunPython(seed, migrations.RunPython.noop)]
