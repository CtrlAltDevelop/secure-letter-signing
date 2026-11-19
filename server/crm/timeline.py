"""The customer timeline. Other apps call `record(...)`; the summary is encrypted at rest."""
from accounts.models import User
from workspace.models import Subject
from workspace.textbox import seal_text

from .models import Customer, CustomerEvent

MAX_SUMMARY = 2000


def record(customer: Customer, kind: str, summary: str, by: User | None = None,
           ref_subject: Subject | None = None) -> CustomerEvent:
    """Append one timeline row (kind: note|call|meeting|task|letter|finance|lead|system)."""
    if kind not in CustomerEvent.KINDS:
        raise ValueError(f"unknown timeline kind {kind!r}")
    return CustomerEvent.objects.create(customer=customer, kind=kind, summary=seal_text(summary[:MAX_SUMMARY]),
                                        by=by, ref_subject=ref_subject)
