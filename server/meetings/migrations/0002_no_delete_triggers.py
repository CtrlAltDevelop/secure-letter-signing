"""Nothing is deleted; signatures are also frozen (no UPDATE)."""
from django.db import migrations

from core import dbguards


class Migration(migrations.Migration):
    dependencies = [("meetings", "0001_initial")]
    operations = [dbguards.guard(
        ["meetings_meeting", "meetings_meetingattendee", "meetings_resolution", "meetings_resolutionowner",
         "meetings_meetingminutessignature", "meetings_meetingtemplate"],
        no_update=["meetings_meetingminutessignature"])]
