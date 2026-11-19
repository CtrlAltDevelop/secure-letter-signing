"""Keep project and customer chats in step with their members (also covered lazily by `mirror.sync` on access)."""
from django.db.models.signals import post_save

from crm.models import CustomerMember
from projects.models import ProjectMember
from workspace.registry import enabled_modules

from . import mirror


def _sync(conv) -> None:
    if conv is not None and "chat" in enabled_modules():
        mirror.sync(conv)


def _project_member_saved(sender, instance, **kwargs) -> None:
    _sync(mirror.chat_of_source(project_id=instance.project_id))


def _customer_member_saved(sender, instance, **kwargs) -> None:
    _sync(mirror.chat_of_source(customer_ref=instance.customer_id))


post_save.connect(_project_member_saved, sender=ProjectMember, dispatch_uid="chat_project_member")
post_save.connect(_customer_member_saved, sender=CustomerMember, dispatch_uid="chat_customer_member")
