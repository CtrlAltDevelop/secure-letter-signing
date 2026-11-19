"""Signing the minutes: sealed exactly like letter signatures (PIN or biometric session, Ed25519 seal)."""
import uuid
from uuid import UUID

from django.db import IntegrityError, transaction
from django.utils import timezone
from ninja.errors import HttpError

from accounts.models import Session, User, audit
from core import cryptoutil
from letters.signing import check_pin

from . import content, notices, store
from .models import Meeting, MeetingAttendee, MeetingMinutesSignature
from .schemas import SignBiometricIn

PAYLOAD_VERSION = 3


def require_turn(meeting: Meeting, user: User) -> None:
    """403/409 unless `user` is a present attendee who may sign the held meeting's current revision."""
    row = MeetingAttendee.objects.filter(meeting=meeting, user=user, active=True).first()
    if row is None or row.attendance != MeetingAttendee.PRESENT:
        raise HttpError(403, "Only attendees marked present can sign the minutes")
    if meeting.status != Meeting.HELD:
        raise HttpError(409, f"The meeting is {meeting.status}")
    if content.current_signatures(meeting).filter(user=user).exists():
        raise HttpError(409, "You already decided")


def build_payload(meeting: Meeting, user: User, session: Session, data: SignBiometricIn, method: str) -> dict:
    return {
        "v": PAYLOAD_VERSION, "kind": "meeting_minutes", "meetingId": str(meeting.id), "revision": meeting.revision,
        "title": meeting.title, "decision": data.decision, "note": data.note,
        "contentHash": content.content_hash(meeting),
        "signer": {"userId": user.id, "email": user.email, "name": user.full_name},
        "method": method, "sessionId": str(session.id), "deviceName": session.device_name,
        "signedAt": timezone.now().isoformat(), "nonce": uuid.uuid4().hex,
    }


@transaction.atomic
def _record(user: User, session: Session, meeting_id: UUID, data: SignBiometricIn, method: str) -> Meeting:
    meeting = store.lock_meeting(user, meeting_id)
    require_turn(meeting, user)
    if data.decision == MeetingMinutesSignature.REJECTED and not data.note.strip():
        raise HttpError(422, "A rejection needs a note")
    payload = build_payload(meeting, user, session, data, method)
    try:
        with transaction.atomic():
            MeetingMinutesSignature.objects.create(
                meeting=meeting, user=user, revision=meeting.revision, decision=data.decision, note=data.note,
                method=method, payload=payload, seal=cryptoutil.seal_payload(payload), nonce=payload["nonce"])
    except IntegrityError as exc:
        raise HttpError(409, "You already decided") from exc
    audit(user, "meeting_signed", str(meeting.id), decision=data.decision, method=method, revision=meeting.revision,
          session=str(session.id), device=session.device_name)
    notices.emit_meeting("meeting.signed", meeting, user, decision=data.decision)
    return meeting


def sign_with_pin(user: User, session: Session, meeting_id: UUID, data: SignBiometricIn, pin: str) -> Meeting:
    """Not atomic as a whole: a wrong PIN must keep its failure count and audit row."""
    meeting = store.visible_meeting(user, meeting_id)
    require_turn(meeting, user)
    check_pin(user, pin, session)
    return _record(user, session, meeting_id, data, "pin")


def sign_with_biometric(user: User, session: Session, meeting_id: UUID, data: SignBiometricIn) -> Meeting:
    if not session.biometric:
        raise HttpError(403, "This session has no biometrics")
    return _record(user, session, meeting_id, data, "biometric")


def all_signed(meeting: Meeting) -> bool:
    present = set(MeetingAttendee.objects.filter(meeting=meeting, active=True, user__isnull=False,
                                                 attendance=MeetingAttendee.PRESENT).values_list("user_id", flat=True))
    signed = set(content.current_signatures(meeting).values_list("user_id", flat=True))
    return bool(present) and present <= signed
