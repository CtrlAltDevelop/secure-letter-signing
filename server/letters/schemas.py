from datetime import datetime
from uuid import UUID

from ninja import Schema
from pydantic import Field

from tasks.schemas import TaskBrief
from workspace.schemas import TextBody, UserRef


class LetterIn(Schema):
    title: str = Field(min_length=1, max_length=200)
    body: dict  # plain JSON object; the server encrypts it at rest
    visibility: str = Field(pattern="^(public|private)$")
    publish_mode: str = Field(pattern="^(now|after_sign)$")
    order: str = Field(pattern="^(parallel|serial)$")
    due_at: datetime | None = None
    parent_id: UUID | None = None
    signer_ids: list[int] = Field(min_length=1)  # in signing order
    viewer_ids: list[int] = []


class SignPinIn(Schema):
    decision: str = Field(pattern="^(approved|rejected)$")
    note: str = Field(default="", max_length=2000)
    pin: str


class SignBiometricIn(Schema):
    decision: str = Field(pattern="^(approved|rejected)$")
    note: str = Field(default="", max_length=2000)


class SignRequestIn(SignBiometricIn):
    approver_session_id: UUID


class SignRequestOut(Schema):
    id: UUID
    letter_id: UUID
    letter_title: str
    decision: str
    note: str
    status: str
    requester_session_id: UUID
    requester_device_name: str
    approver_session_id: UUID
    created_at: datetime
    expires_at: datetime
    resolved_at: datetime | None


class ParticipantOut(Schema):
    user_id: int
    email: str
    full_name: str
    role: str
    position: int
    decision: str
    decided_at: datetime | None


class SignatureOut(Schema):
    signer_id: int
    decision: str
    note: str
    method: str
    device_name: str
    signed_at: str
    seal: str
    payload: dict


class LetterBrief(Schema):
    id: UUID
    no: int
    title: str
    status: str
    creator_id: int
    parent_id: UUID | None
    visibility: str
    unlisted: bool
    created_at: datetime
    sent_at: datetime | None
    # Letters v2: workspace anchor, the caller's labels, secretariat number ("1405/0012"), referral count, archive flag
    subject_id: UUID | None = None
    label_ids: list[int] = []
    number_label: str = ""
    referral_count: int = 0
    archived: bool = False


class AttachmentOut(Schema):
    id: UUID
    content_type: str
    label: str
    size: int


class LetterOut(LetterBrief):
    publish_mode: str
    order: str
    due_at: datetime | None
    body: dict  # plaintext
    participants: list[ParticipantOut]
    signatures: list[SignatureOut]
    children: list[LetterBrief]
    attachments: list[AttachmentOut]
    paraphs: list["ParaphOut"] = []
    tasks: list[TaskBrief] = []  # linked tasks the caller may see
    customer_refs: list[UUID] = []


class AdminLetterOut(LetterBrief):
    """What the manager sees: title and participants only, never the body."""

    creator_email: str
    participants: list[ParticipantOut]


class ParaphOut(Schema):
    signer_id: int
    signer_name: str
    method: str
    device_name: str
    paraphed_at: str
    seal: str
    payload: dict


class ParaphPinIn(Schema):
    pin: str


class ReferIn(Schema):
    user_ids: list[int] = Field(min_length=1, max_length=50)
    note: str = Field(default="", max_length=2000)


class ReferralRespondIn(Schema):
    status: str = Field(pattern="^(done|declined)$")
    note: str = Field(default="", max_length=2000)


class ReferralOut(Schema):
    id: int
    letter_id: UUID
    from_user: UserRef
    to_user: UserRef
    note: TextBody
    status: str
    response_note: TextBody
    created_at: datetime
    responded_at: datetime | None


class ArchiveIn(Schema):
    archived: bool = True


class LetterTaskIn(Schema):
    task_id: UUID


class CustomerRefsIn(Schema):
    customer_refs: list[UUID] = Field(max_length=50)


class CustomerRefsOut(Schema):
    customer_refs: list[UUID]


class EntryIn(Schema):
    direction: str = Field(pattern="^(in|out)$")
    title: str = Field(default="", max_length=200)
    party_name: str = Field(default="", max_length=200)
    party_ref: str = Field(default="", max_length=100)
    letter_id: UUID | None = None
    summary: str = Field(default="", max_length=20_000)


class EntryPatch(Schema):
    title: str | None = Field(None, min_length=1, max_length=200)
    party_name: str | None = Field(None, max_length=200)
    party_ref: str | None = Field(None, max_length=100)
    summary: str | None = Field(None, max_length=20_000)


class EntryOut(Schema):
    id: UUID
    subject_id: UUID
    direction: str
    number: str
    jalali_year: int
    seq: int
    registered_at: datetime
    registered_by: UserRef
    title: str
    party_name: str
    party_ref: str
    letter_id: UUID | None
    summary: TextBody
    customer_refs: list[UUID]
    label_ids: list[int]
    active: bool
