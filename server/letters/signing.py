"""Signing rules shared by the PIN, biometric and remote-approval paths, plus the seal and what follows a decision."""
import uuid

from django.contrib.auth.hashers import check_password
from django.db import IntegrityError, transaction
from django.utils import timezone
from ninja.errors import HttpError

from accounts import ratelimit
from accounts.models import Session, User, audit
from accounts.notify import notify
from core import cryptoutil

from . import events, rules
from .models import Letter, Participant, Signature

PIN_SCOPE, PIN_MAX_FAILURES = "sign-pin", 5
PIN_SESSION_SCOPE, PIN_MAX_FAILURES_PER_SESSION = "sign-pin-session", 10
PAYLOAD_VERSION = 3


# --- who may sign now ----------------------------------------------------------------------------------------


def require_turn(letter: Letter, user: User) -> Participant:
    """The caller's signer row, or the HttpError explaining why they cannot sign right now."""
    me = letter.participants.filter(user=user, role=Participant.SIGNER).first()
    if me is None:
        raise HttpError(403, "You are not a signer of this letter")
    if rules.SIGN not in rules.grants_of(user):
        raise HttpError(403, "You no longer have the letter.sign permission")
    if letter.status != Letter.IN_SIGNING:
        raise HttpError(409, f"Letter is {letter.status}")
    if me.decision:
        raise HttpError(409, "You already decided")
    if user.id not in rules.next_signer_ids(letter):
        raise HttpError(409, "It is not your turn yet")
    return me


# --- the signing PIN -----------------------------------------------------------------------------------------


def check_pin(user: User, pin: str, session: Session) -> None:
    """Counts every attempt BEFORE hashing, atomically: 5 per user and 10 per session per 15 minutes, then 429.
    Only failures stay counted: a correct PIN gives its attempt back, so signing many letters is never throttled
    while wrong guesses (even concurrent ones) are. Call OUTSIDE a transaction so the audit row of a failure is kept."""
    if not user.signing_pin_hash:
        raise HttpError(409, "Set your signing PIN first")
    ident = str(user.id)
    ratelimit.hit(PIN_SCOPE, ident, PIN_MAX_FAILURES)
    ratelimit.hit(PIN_SESSION_SCOPE, str(session.id), PIN_MAX_FAILURES_PER_SESSION)
    if not check_password(pin, user.signing_pin_hash):
        audit(user, "sign_pin_failed", ident)
        raise HttpError(403, "Wrong signing PIN")
    ratelimit.refund(PIN_SCOPE, ident)
    ratelimit.refund(PIN_SESSION_SCOPE, str(session.id))


# --- seal ----------------------------------------------------------------------------------------------------


def build_payload(letter: Letter, user: User, session: Session, *, decision: str, note: str, method: str) -> dict:
    return {
        "v": PAYLOAD_VERSION, "letterId": str(letter.id), "title": letter.title, "decision": decision, "note": note,
        "contentHash": cryptoutil.content_hash(cryptoutil.decrypt_body(letter.body)),
        "parentId": str(letter.parent_id) if letter.parent_id else None,
        "signer": {"userId": user.id, "email": user.email, "name": user.full_name},
        "method": method, "sessionId": str(session.id), "deviceName": session.device_name,
        "signedAt": timezone.now().isoformat(), "nonce": uuid.uuid4().hex,
    }


def record_signature(letter: Letter, user: User, session: Session, *, decision: str, note: str, method: str) -> None:
    """Seal and store the signature, then advance the letter. `session` is the one that proved identity (for a
    remote approval: the approver's). The caller holds the letter lock and has run `require_turn`."""
    me = require_turn(letter, user)
    payload = build_payload(letter, user, session, decision=decision, note=note, method=method)
    now = timezone.now()
    try:
        with transaction.atomic():
            Signature.objects.create(letter=letter, signer=user, decision=decision, payload=payload, method=method,
                                     seal=cryptoutil.seal_payload(payload), nonce=payload["nonce"])
    except IntegrityError as exc:
        raise HttpError(409, "You already decided") from exc
    me.decision, me.decided_at = decision, now
    me.save(update_fields=["decision", "decided_at"])
    audit(user, "letter_signed", str(letter.id), decision=decision, method=method, session=str(session.id),
          device=session.device_name)
    events.emit(letter, "signed" if decision == "approved" else "rejected", user, decision=decision)
    advance(letter, user, decision, now)


# --- after a decision ----------------------------------------------------------------------------------------


def notify_next(letter: Letter, prefix: str) -> None:
    users = User.objects.filter(pk__in=rules.next_signer_ids(letter))
    notify(users, "sign_request", f"{prefix}: {letter.title}", letter_id=str(letter.id))


def notify_viewers(letter: Letter, prefix: str) -> None:
    if letter.unlisted:
        return
    ids = rules.audience_ids(letter) - {letter.creator_id} - set(
        letter.participants.filter(role="signer").values_list("user_id", flat=True))
    notify(User.objects.filter(pk__in=ids), "letter_published", f"{prefix}: {letter.title}", letter_id=str(letter.id))


def advance(letter: Letter, actor: User, decision: str, now) -> None:
    if decision == "rejected":  # final: the creator may start a new chained letter
        letter.status, letter.closed_at = Letter.REJECTED, now
        letter.save(update_fields=["status", "closed_at"])
        signer_ids = letter.participants.filter(role="signer").values_list("user_id", flat=True)
        people = User.objects.filter(pk__in={letter.creator_id, *signer_ids})
        notify(people, "letter_rejected", f"Rejected: {letter.title}", letter_id=str(letter.id))
        return
    if letter.participants.filter(role=Participant.SIGNER, decision="").exists():
        if letter.order == "serial":
            notify_next(letter, "Your turn to sign")
        return
    letter.status, letter.closed_at = Letter.PUBLISHED, now
    update = ["status", "closed_at"]
    if letter.shown_at is None:
        letter.shown_at = now
        update.append("shown_at")
    letter.save(update_fields=update)
    audit(actor, "letter_published", str(letter.id))
    events.emit(letter, "published", actor)
    notify([letter.creator], "letter_published", f"Fully signed: {letter.title}", letter_id=str(letter.id))
    notify_viewers(letter, "Published")
