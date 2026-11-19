from django.apps import AppConfig


class GanttConfig(AppConfig):
    name = "gantt"
    default_auto_field = "django.db.models.BigAutoField"

    def ready(self) -> None:
        from . import readiness

        readiness.connect()
