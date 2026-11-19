"""Timeline rows for status changes of linked tasks, meetings and letters (no actor is known here, so `by` is null)."""
from django.db.models.signals import pre_save

from . import timeline
from .models import Customer


def _old_status(sender, instance) -> str | None:
    if instance.pk is None:
        return None
    return sender.objects.filter(pk=instance.pk).values_list("status", flat=True).first()


def _record(customer_ids, kind: str, label: str, title: str, old: str, new: str, subject) -> None:
    for customer in Customer.objects.filter(pk__in=customer_ids).select_related("subject"):
        timeline.record(customer, kind, f"{label} status {old} -> {new}: {title}", ref_subject=subject)


def _on_task_or_meeting(kind: str, label: str):
    def receiver(sender, instance, **kwargs) -> None:
        if not instance.customer_id:
            return
        old = _old_status(sender, instance)
        if old is not None and old != instance.status:
            _record([instance.customer_id], kind, label, instance.title, old, instance.status, instance.subject)

    return receiver


def _on_letter(sender, instance, **kwargs) -> None:
    from letters.models import CustomerLink

    if instance.subject_id is None:
        return
    old = _old_status(sender, instance)
    if old is None or old == instance.status:
        return
    ids = (CustomerLink.objects.filter(subject_id=instance.subject_id, active=True, customer_ref__isnull=False)
           .values_list("customer_ref", flat=True))
    _record(list(ids), "letter", "Letter", instance.title, old, instance.status, instance.subject)


def connect() -> None:
    from letters.models import Letter
    from meetings.models import Meeting
    from tasks.models import Task

    pre_save.connect(_on_task_or_meeting("task", "Task"), sender=Task, weak=False,
                     dispatch_uid="crm_task_status")
    pre_save.connect(_on_task_or_meeting("meeting", "Meeting"), sender=Meeting, weak=False,
                     dispatch_uid="crm_meeting_status")
    pre_save.connect(_on_letter, sender=Letter, weak=False, dispatch_uid="crm_letter_status")


connect()
