"""Append-only: no DELETE on any workspace table, no UPDATE on events and change history."""
from django.db import migrations

from core import dbguards

TABLES = [
    "workspace_subject", "workspace_label", "workspace_subjectlabel", "workspace_file", "workspace_comment",
    "workspace_changehistory", "workspace_seenby", "workspace_event", "workspace_eventrecipient", "workspace_reminder",
]
NO_UPDATE = ["workspace_event", "workspace_eventrecipient", "workspace_changehistory"]


class Migration(migrations.Migration):
    dependencies = [("workspace", "0001_initial")]
    operations = [dbguards.guard(TABLES, no_update=NO_UPDATE)]
