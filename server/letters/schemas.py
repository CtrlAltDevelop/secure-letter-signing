from datetime import datetime
from uuid import UUID

from ninja import Schema
from pydantic import Field


class WrapIn(Schema):
    key_id: UUID
    wrap: dict


class LetterIn(Schema):
    title: str = Field(min_length=1, max_length=200)
    body: dict  # {"iv", "ct"}
    visibility: str = Field(pattern="^(public|private)$")
    publish_mode: str = Field(pattern="^(now|after_sign)$")
    order: str = Field(pattern="^(parallel|serial)$")
    due_at: datetime | None = None
    parent_id: UUID | None = None
    signer_ids: list[int] = Field(min_length=1)  # in signing order
    viewer_ids: list[int] = []
    wraps: list[WrapIn]
    company_key_version: int | None = None
    company_wrap: dict | None = None


class SignIn(Schema):
    key_id: UUID
    payload: dict
    signature: str


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
    key_id: UUID
    fingerprint: str
    decision: str
    payload: dict
    signature: str
    created_at: datetime


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
    iv: str
    size: int


class LetterOut(LetterBrief):
    publish_mode: str
    order: str
    due_at: datetime | None
    body: dict
    company_key_version: int | None
    company_wrap: dict | None
    participants: list[ParticipantOut]
    signatures: list[SignatureOut]
    my_wraps: list[WrapIn]
    children: list[LetterBrief]
    attachments: list[AttachmentOut]


class AdminLetterOut(LetterBrief):
    """What the manager sees: title and participants only, never the body."""

    creator_email: str
    participants: list[ParticipantOut]
