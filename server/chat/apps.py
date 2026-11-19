from django.apps import AppConfig


class ChatConfig(AppConfig):
    name = "chat"
    default_auto_field = "django.db.models.BigAutoField"

    def ready(self) -> None:
        from workspace import registry

        from . import module, signals  # noqa: F401  (signals keeps project/customer chats in step with members)

        registry.register(module.spec())
