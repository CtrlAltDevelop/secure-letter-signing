from django.apps import AppConfig


class SalesConfig(AppConfig):
    name = "sales"
    default_auto_field = "django.db.models.BigAutoField"

    def ready(self) -> None:
        from workspace import registry

        from . import module

        registry.register(module.spec())
