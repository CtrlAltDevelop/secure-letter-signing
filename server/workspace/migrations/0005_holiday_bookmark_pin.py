import django.db.models.deletion
import django.utils.timezone
from django.conf import settings
from django.db import migrations, models

from core import dbguards


class Migration(migrations.Migration):

    dependencies = [
        ('workspace', '0004_mentions'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='Holiday',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('date', models.DateField(db_index=True)),
                ('title', models.CharField(max_length=100)),
                ('kind', models.CharField(choices=[('official', 'official'), ('religious', 'religious'), ('company', 'company')], default='official', max_length=10)),
                ('active', models.BooleanField(default=True)),
            ],
            options={
                'constraints': [models.UniqueConstraint(fields=('date', 'title'), name='one_holiday_title_per_date')],
            },
        ),
        migrations.CreateModel(
            name='Bookmark',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('target_module', models.CharField(max_length=32)),
                ('target_id', models.CharField(max_length=64)),
                ('title', models.CharField(blank=True, max_length=200)),
                ('note', models.JSONField(blank=True, default=dict)),
                ('created_at', models.DateTimeField(default=django.utils.timezone.now)),
                ('active', models.BooleanField(default=True)),
                ('subject', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.PROTECT, related_name='+', to='workspace.subject')),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name='+', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'constraints': [models.UniqueConstraint(fields=('user', 'target_module', 'target_id'), name='one_bookmark_per_user_target')],
            },
        ),
        migrations.CreateModel(
            name='Pin',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('rank', models.BigIntegerField(default=0)),
                ('active', models.BooleanField(default=True)),
                ('subject', models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name='+', to='workspace.subject')),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name='+', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'constraints': [models.UniqueConstraint(fields=('user', 'subject'), name='one_pin_per_user_subject')],
            },
        ),
        dbguards.guard(["workspace_holiday", "workspace_bookmark", "workspace_pin"]),
    ]
