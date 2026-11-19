"""Nothing is deleted: the database refuses DELETE on every projects table (rows may be updated)."""
from django.db import migrations

from core import dbguards


class Migration(migrations.Migration):
    dependencies = [("projects", "0001_initial")]
    operations = [dbguards.guard(["projects_projectgroup", "projects_project", "projects_projectmember",
                                  "projects_boardcolumn"])]
