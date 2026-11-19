from django.apps import AppConfig


class MeetingsConfig(AppConfig):
    name = "meetings"
    default_auto_field = "django.db.models.BigAutoField"

    def ready(self) -> None:
        from workspace import registry

        from . import module, resolutions

        registry.register(module.spec())
        resolutions.connect_task_mirror()
