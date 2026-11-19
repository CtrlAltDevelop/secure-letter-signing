"""Every existing letter gets a workspace Subject (new letters get theirs at creation)."""
from django.db import migrations


def create_subjects(apps, schema_editor) -> None:
    Letter, Subject = apps.get_model("letters", "Letter"), apps.get_model("workspace", "Subject")
    for letter in Letter.objects.filter(subject__isnull=True).iterator():
        subject = Subject.objects.create(module="letters", kind="letter", created_at=letter.created_at)
        Letter.objects.filter(pk=letter.pk).update(subject=subject)


class Migration(migrations.Migration):
    dependencies = [("letters", "0004_letters_v2")]
    operations = [migrations.RunPython(create_subjects, migrations.RunPython.noop)]
