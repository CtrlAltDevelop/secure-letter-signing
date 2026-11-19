import datetime as dt
from datetime import datetime
from uuid import UUID

from ninja import Field, Schema

from workspace.schemas import TextBody, UserRef

MAX_AMOUNT = 10**15


class DocIn(Schema):
    kind: str
    direction: str
    amount: int = Field(gt=0, le=MAX_AMOUNT)
    date: dt.date
    due_date: dt.date | None = None
    description: TextBody | None = None
    customer_id: UUID | None = None
    status: str | None = None  # confirmed|pending; default: cash confirmed, cheque/probable pending


class DocPatch(Schema):
    kind: str | None = None
    direction: str | None = None
    amount: int | None = Field(default=None, gt=0, le=MAX_AMOUNT)
    date: dt.date | None = None
    due_date: dt.date | None = None
    description: TextBody | None = None
    customer_id: UUID | None = None


class ConfirmIn(Schema):
    date: dt.date | None = None  # the actual date; default today


class VoidIn(Schema):
    reason: str = Field(min_length=1, max_length=2000)


class DocOut(Schema):
    id: UUID
    subject_id: UUID
    customer_id: UUID | None
    customer_name: str | None
    kind: str
    direction: str
    amount: int
    date: dt.date
    due_date: dt.date | None
    description: TextBody
    status: str
    overdue: bool
    created_by: UserRef
    created_at: datetime
    voided_by: UserRef | None
    voided_at: datetime | None
    void_reason: TextBody | None
    label_ids: list[int]
    file_count: int


class CustomerFinanceOut(Schema):
    customer_id: UUID
    documents: list[DocOut]
    totals: dict


class SummaryOut(Schema):
    calendar: str
    group_by: str
    today: dt.date
    totals: dict
    buckets: list[dict]


class MonthlyOut(Schema):
    year: int
    months: list[dict]
    totals: dict


class ChartOut(Schema):
    labels: list[str]
    receipts: list[int]
    payments: list[int]
    points: list[dict]
