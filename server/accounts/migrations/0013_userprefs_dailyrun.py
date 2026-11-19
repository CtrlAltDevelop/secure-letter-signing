import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models

from core import dbguards

import accounts.models


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0012_org_titles_status'),
        ('letters', '0002_no_delete_triggers'),
    ]

    operations = [
        migrations.CreateModel(
            name='UserPrefs',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('theme', models.CharField(choices=[('light', 'light'), ('dark', 'dark'), ('auto', 'auto')], default='auto', max_length=5)),
                ('birthday', models.DateField(blank=True, null=True)),
                ('birthday_visible', models.BooleanField(default=True)),
                ('dnd_until', models.DateTimeField(blank=True, null=True)),
                ('personal_email', models.EmailField(blank=True, max_length=254)),
                ('personal_email_verified', models.BooleanField(default=False)),
                ('background', models.FileField(blank=True, upload_to=accounts.models.background_path)),
                ('background_type', models.CharField(blank=True, max_length=20)),
                ('background_active', models.BooleanField(default=False)),
                ('user', models.OneToOneField(on_delete=django.db.models.deletion.PROTECT, related_name='prefs', to=settings.AUTH_USER_MODEL)),
            ],
        ),
        migrations.CreateModel(
            name='DailyRun',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=40)),
                ('date', models.DateField()),
            ],
            options={
                'constraints': [models.UniqueConstraint(fields=('name', 'date'), name='one_daily_run_per_name_date')],
            },
        ),
        dbguards.guard(["accounts_userprefs", "accounts_dailyrun"]),
    ]
