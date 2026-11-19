"""FinanceDoc -> DocOut."""
from collections.abc import Sequence
from datetime import date

from accounts.models import User
from workspace.access import my_label_ids
from workspace.models import File
from workspace.schemas import TextBody, user_ref
from workspace.textbox import open_text

from .models import FinanceDoc
from .schemas import DocOut


def is_overdue(doc: FinanceDoc, today: date) -> bool:
    return doc.status == FinanceDoc.PENDING and doc.due_date is not None and doc.due_date < today


def doc_out(user: User, doc: FinanceDoc, today: date) -> DocOut:
    return DocOut(
        id=doc.id, subject_id=doc.subject_id, customer_id=doc.customer_id,
        customer_name=doc.customer.name if doc.customer_id else None, kind=doc.kind, direction=doc.direction,
        amount=doc.amount, date=doc.date, due_date=doc.due_date, description=TextBody(text=open_text(doc.description)),
        status=doc.status, overdue=is_overdue(doc, today), created_by=user_ref(doc.created_by),
        created_at=doc.created_at, voided_by=user_ref(doc.voided_by) if doc.voided_by_id else None,
        voided_at=doc.voided_at, void_reason=TextBody(text=open_text(doc.void_reason)) if doc.voided_at else None,
        label_ids=my_label_ids(user, doc.subject),
        file_count=File.objects.filter(subject_id=doc.subject_id, active=True).count())


def docs_out(user: User, docs: Sequence[FinanceDoc], today: date) -> list[DocOut]:
    return [doc_out(user, d, today) for d in docs]
