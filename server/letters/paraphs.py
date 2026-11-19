"""Paraph (initialling) of a letter: sealed like a signature, once per person, by signers, viewers and referees."""
import uuid

from django.db import IntegrityError, transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja.errors import HttpError

from accounts.models import Session, User, audit
from core import cryptoutil

from . import notices, rules
from .models import Letter, Paraph, Participant
from .schemas import ParaphOut

PARAPH_STATUSES = (Letter.IN_SIGNING, Letter.PUBLISHED)


def require_can_paraph(letter: Letter, user: User) -> None:
    """The caller already passed `can_see`. 409 when the letter is not in signing/published or already initialled."""
    is_signer_or_viewer = letter.participants.filter(
        user=user, role__in=(Participant.SIGNER, Participant.VIEWER)).exists()
    if not (is_signer_or_viewer or rules.is_referee(user, letter)):
        raise HttpError(403, "Only signers, viewers and referees can paraph a letter")
    if letter.status not in PARAPH_STATUSES:
        raise HttpError(409, f"Letter is {letter.status}")
    if letter.paraphs.filter(user=user).exists():
        raise HttpError(409, "You already paraphed this letter")


def build_payload(letter: Letter, user: User, session: Session, method: str) -> dict:
    return {
        "v": 3, "kind": "paraph", "letterId": str(letter.id),
        "contentHash": cryptoutil.content_hash(cryptoutil.decrypt_body(letter.body)),
        "signer": {"userId": user.id, "email": user.email, "name": user.full_name},
        "method": method, "sessionId": str(session.id), "deviceName": session.device_name,
        "signedAt": timezone.now().isoformat(), "nonce": uuid.uuid4().hex,
    }


@transaction.atomic
def record(letter_id, user: User, session: Session, method: str) -> Paraph:
    """Seal and store the paraph under the letter lock (the caller has proved identity with PIN or biometrics)."""
    letter = get_object_or_404(Letter.objects.select_for_update(), pk=letter_id)
    if not rules.can_see(user, letter):
        raise HttpError(404, "Letter not found")
    require_can_paraph(letter, user)
    payload = build_payload(letter, user, session, method)
    try:
        with transaction.atomic():
            row = Paraph.objects.create(letter=letter, user=user, method=method, payload=payload, nonce=payload["nonce"],
                                        seal=cryptoutil.seal_payload(payload))
    except IntegrityError as exc:
        raise HttpError(409, "You already paraphed this letter") from exc
    audit(user, "letter_paraphed", str(letter.id), method=method, session=str(session.id), device=session.device_name)
    notices.history(letter.subject, user, "paraph", None, {"user_id": user.id})
    notices.announce(letter, "paraphed", user, user_id=user.id)
    return row


def paraph_out(p: Paraph) -> ParaphOut:
    return ParaphOut(signer_id=p.user_id, signer_name=p.user.full_name or p.user.email, method=p.method,
                     device_name=p.payload.get("deviceName", ""), paraphed_at=str(p.payload.get("signedAt", "")),
                     seal=p.seal, payload=p.payload)


def paraphs_of(letter: Letter) -> list[ParaphOut]:
    return [paraph_out(p) for p in letter.paraphs.select_related("user").order_by("id")]


def certificate_rows(letter: Letter, current_hash: str) -> list[dict]:
    """Paraphs re-verified now: the seal, the content hash AND that the sealed payload really is this person's
    paraph of this letter (a seal copied from another payload kind or letter must not verify)."""
    rows = []
    for p in letter.paraphs.select_related("user").order_by("id"):
        who = p.payload.get("signer", {})
        ok = (cryptoutil.verify_seal(p.payload, p.seal) and p.payload.get("kind") == "paraph"
              and p.payload.get("letterId") == str(letter.id) and p.payload.get("contentHash") == current_hash
              and who.get("userId") == p.user_id)
        rows.append({"signer": p.user.email, "method": p.method, "device": p.payload.get("deviceName", ""),
                     "paraphed_at": p.payload.get("signedAt"), "payload": p.payload, "seal": p.seal, "verified": ok})
    return rows
