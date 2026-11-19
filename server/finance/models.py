"""Finance documents (receipts and payments). Nothing is deleted: a payment is cancelled by voiding it (status change).

Amounts, dates and kinds are plaintext so they can be aggregated; description and void reason are encrypted.
"""
import uuid

from django.conf import settings
from django.db import models
from django.db.models import Q
from django.utils import timezone

User = settings.AUTH_USER_MODEL


class FinanceDoc(models.Model):
    CASH, CHEQUE, PROBABLE, VOID = "cash", "cheque", "probable", "void"
    KINDS = [(k, k) for k in (CASH, CHEQUE, PROBABLE, VOID)]
    DUE_KINDS = (CHEQUE, PROBABLE)  # these carry a due_date
    RECEIPT, PAYMENT = "receipt", "payment"
    DIRECTIONS = [(RECEIPT, RECEIPT), (PAYMENT, PAYMENT)]
    CONFIRMED, PENDING, VOIDED = "confirmed", "pending", "void"
    STATUSES = [(s, s) for s in (CONFIRMED, PENDING, VOIDED)]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    subject = models.OneToOneField("workspace.Subject", on_delete=models.PROTECT, related_name="finance_doc")
    customer = models.ForeignKey("crm.Customer", null=True, blank=True, on_delete=models.PROTECT,
                                 related_name="finance_docs")
    kind = models.CharField(max_length=10, choices=KINDS)
    direction = models.CharField(max_length=10, choices=DIRECTIONS)
    amount = models.BigIntegerField()  # rials
    date = models.DateField()
    due_date = models.DateField(null=True, blank=True)
    description = models.JSONField(default=dict, blank=True)  # encrypted via workspace.textbox
    status = models.CharField(max_length=10, choices=STATUSES)
    created_by = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(default=timezone.now)
    voided_by = models.ForeignKey(User, null=True, blank=True, on_delete=models.PROTECT, related_name="+")
    voided_at = models.DateTimeField(null=True, blank=True)
    void_reason = models.JSONField(default=dict, blank=True)  # encrypted via workspace.textbox

    class Meta:
        constraints = [models.CheckConstraint(condition=Q(amount__gt=0), name="finance_amount_positive")]
        indexes = [models.Index(fields=["status", "date"], name="finance_status_date"),
                   models.Index(fields=["due_date"], name="finance_due_date")]
