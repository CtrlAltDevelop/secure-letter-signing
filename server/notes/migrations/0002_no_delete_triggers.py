"""Nothing is deleted: the database refuses DELETE on every notes table."""
from django.db import migrations

from core import dbguards


class Migration(migrations.Migration):
    dependencies = [("notes", "0001_initial")]
    operations = [dbguards.guard(["notes_note", "notes_notechecklistitem"])]
