from django.apps import AppConfig


class CrmConfig(AppConfig):
    name = "crm"
    default_auto_field = "django.db.models.BigAutoField"

    def ready(self) -> None:
        from workspace import registry

        from . import module, signals  # noqa: F401  (signals connects the status-change receivers)

        registry.register(module.spec())
