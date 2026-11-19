"""Nothing is deleted: the database refuses DELETE on every polls table (answers are deactivated when replaced)."""
from django.db import migrations

from core import dbguards


class Migration(migrations.Migration):
    dependencies = [("polls", "0001_initial")]
    operations = [dbguards.guard(
        ["polls_poll", "polls_pollquestion", "polls_polloption", "polls_pollanswer", "polls_pollsubmission",
         "polls_polltemplate"])]
