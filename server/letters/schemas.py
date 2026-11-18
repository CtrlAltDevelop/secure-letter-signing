from datetime import datetime
from uuid import UUID

from ninja import Schema
from pydantic import Field


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


class AdminLetterOut(LetterBrief):
    """What the manager sees: title and participants only, never the body."""

    creator_email: str
    participants: list[ParticipantOut]
