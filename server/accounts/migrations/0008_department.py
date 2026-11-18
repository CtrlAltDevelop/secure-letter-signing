import django.db.models.deletion
from django.db import migrations, models


def copy_departments(apps, schema_editor):
    Department, User = apps.get_model("accounts", "Department"), apps.get_model("accounts", "User")
    for user in User.objects.exclude(department_old=""):
        name = user.department_old.strip()[:100]
        if name:
            user.department, _ = Department.objects.get_or_create(name=name)
            user.save(update_fields=["department"])


class Migration(migrations.Migration):
    dependencies = [("accounts", "0007_company_letterhead")]

    operations = [
        migrations.CreateModel(
            name="Department",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("name", models.CharField(max_length=100, unique=True)),
                ("active", models.BooleanField(default=True)),
            ],
            options={"ordering": ("name",)},
        ),
        migrations.RenameField("user", "department", "department_old"),
        migrations.AddField(
            "user", "department",
            models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.PROTECT,
                              related_name="users", to="accounts.department"),
        ),
        migrations.RunPython(copy_departments, migrations.RunPython.noop),
        migrations.RemoveField("user", "department_old"),
    ]
