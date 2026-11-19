"""Nothing is deleted (DB refuses DELETE on every chat table); permission chat.create_group for every user."""
from django.db import migrations

from core import dbguards

TABLES = ["chat_conversation", "chat_conversationmember", "chat_message", "chat_pinnedmessage", "chat_messageread"]


def seed(apps, schema_editor):
    Permission = apps.get_model("accounts", "Permission")
    User = apps.get_model("accounts", "User")
    perm, _ = Permission.objects.get_or_create(
        code="chat.create_group", defaults={"description": "Create chat groups and channels"})
    for user in User.objects.all():
        user.grants.add(perm)


class Migration(migrations.Migration):
    dependencies = [("chat", "0001_initial"), ("accounts", "0012_org_titles_status")]
    operations = [dbguards.guard(TABLES), migrations.RunPython(seed, migrations.RunPython.noop)]
