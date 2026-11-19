from django.apps import AppConfig


class TasksConfig(AppConfig):
    name = "tasks"
    default_auto_field = "django.db.models.BigAutoField"

    def ready(self) -> None:
        from workspace import registry

        from . import module

        registry.register(module.spec())
