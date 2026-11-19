from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0014_security_guests'),
    ]

    operations = [
        migrations.AddField(
            model_name='invitecode',
            name='guest',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='invitecode',
            name='guest_expires_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
