"""Letters: create/send/sign/publish, visibility, unlist, attachments, history. Bodies and files are encrypted at rest."""
import logging
from uuid import UUID

from django.conf import settings
from django.db import transaction
from django.db.models import Max
from django.http import HttpResponse
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja import File, Form, Router, Schema
from ninja.errors import HttpError
from ninja.files import UploadedFile

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, require_manager, user_of
from accounts.models import User, audit
from core import cryptoutil, filestore

from workspace.models import Subject

from . import access, briefs, inbox, events, paraphs, rules, secretariat, signing, task_links
from .models import Attachment, Letter, LetterEvent, Participant
from .schemas import (AdminLetterOut, AttachmentOut, LetterBrief, LetterIn, LetterOut, ParticipantOut, SignatureOut,
                      SignBiometricIn, SignPinIn, SignRequestIn, SignRequestOut)
from .sign_requests import create_request, request_out

logger = logging.getLogger(__name__)
router = Router(tags=["letters"], auth=BearerAuth())
MAX_PEOPLE, MAX_BODY_CHARS, MAX_ATTACHMENTS = 500, 2_000_000, 20
ATTACHMENT_TYPES = filestore.ATTACHMENT_TYPES


def _brief(user: User, letter: Letter) -> LetterBrief:
    return briefs.brief_of(user, letter)


def _participants(letter: Letter) -> list[ParticipantOut]:
    rows = letter.participants.exclude(role="removed").select_related("user").order_by("role", "position", "id")
    return [ParticipantOut(user_id=p.user_id, email=p.user.email, full_name=p.user.full_name, role=p.role,
                           position=p.position, decision=p.decision, decided_at=p.decided_at) for p in rows]


_get_visible = access.get_visible


def _lock_own_draft(user: User, letter_id: UUID, sent_message: str) -> Letter:
    """The caller's letter, row-locked (call inside `transaction.atomic`), with the draft check done AFTER the lock
    so a concurrent send/cancel cannot slip between check and write."""
    letter = get_object_or_404(Letter.objects.select_for_update(), pk=letter_id, creator=user)
    if letter.status != Letter.DRAFT:
        raise HttpError(409, sent_message)
    return letter


def _require(user: User, code: str) -> None:
    if code not in rules.grants_of(user):
        raise HttpError(403, "Permission denied")


# --- create / edit draft -------------------------------------------------------------------------------------


def _apply(letter: Letter, user: User, data: LetterIn) -> None:
    """Validates and stores everything for a draft (new or replaced)."""
    if len(cryptoutil.canonical_json(data.body)) > MAX_BODY_CHARS:
        raise HttpError(413, "body is too large")
    if len(data.signer_ids) > MAX_PEOPLE or len(data.viewer_ids) > MAX_PEOPLE:
        raise HttpError(422, "Too many participants")
    signer_ids = list(dict.fromkeys(data.signer_ids))
    viewer_ids = [v for v in dict.fromkeys(data.viewer_ids) if v not in signer_ids and v != user.id]
    if data.visibility == "public" and data.viewer_ids:
        raise HttpError(422, "Public letters have no viewer list")
    people = {u.id: u for u in User.objects.filter(pk__in=[*signer_ids, *viewer_ids], is_active=True)}
    if len(people) != len(signer_ids) + len(viewer_ids):
        raise HttpError(422, "Unknown or inactive participant")
    if any(rules.SIGN not in rules.grants_of(people[i]) for i in signer_ids):
        raise HttpError(422, "Every signer needs the letter.sign permission")
    if data.parent_id:
        parent = Letter.objects.filter(pk=data.parent_id).first()
        if parent is None or not rules.can_see(user, parent):
            raise HttpError(422, "Parent letter not found")
        letter.parent = parent
    letter.title, letter.body = data.title.strip(), cryptoutil.encrypt_body(data.body)
    letter.visibility, letter.publish_mode, letter.order = data.visibility, data.publish_mode, data.order
    letter.due_at = data.due_at
    letter.save()
    # Nothing is deleted: people dropped from the draft keep a row with role "removed" (ignored everywhere).
    Participant.objects.filter(letter=letter).update(role="removed")
    for pos, uid in enumerate(signer_ids):
        Participant.objects.update_or_create(letter=letter, user=people[uid], defaults={
            "role": Participant.SIGNER, "position": pos, "decision": ""})
    for uid in viewer_ids:
        Participant.objects.update_or_create(letter=letter, user=people[uid], defaults={
            "role": Participant.VIEWER, "position": 0, "decision": ""})
@router.post("", response={201: LetterBrief})
@transaction.atomic
def create_letter(request, data: LetterIn):
    user = user_of(request)
    _require(user, rules.CREATE)
    subject = Subject.objects.create(module="letters", kind="letter")
    letter = Letter(creator=user, subject=subject, no=(Letter.objects.aggregate(m=Max("no"))["m"] or 0) + 1, body={},
                    title=data.title, visibility=data.visibility, publish_mode=data.publish_mode, order=data.order)
    letter.save()
    _apply(letter, user, data)
    audit(user, "letter_created", str(letter.id), no=letter.no)
    return 201, _brief(user, letter)


@router.put("/{uuid:letter_id}", response=LetterBrief)
@transaction.atomic
def update_draft(request, letter_id: UUID, data: LetterIn):
    user = user_of(request)
    letter = _lock_own_draft(user, letter_id, "A sent letter is immutable; write a new chained letter")
    _apply(letter, user, data)
    return _brief(user, letter)


# --- send ------------------------------------------------------------------------------------------------------


@router.post("/{uuid:letter_id}/send", response=LetterBrief)
@transaction.atomic
def send_letter(request, letter_id: UUID):
    user = user_of(request)
    letter = get_object_or_404(Letter.objects.select_for_update(), pk=letter_id, creator=user)
    if letter.status != Letter.DRAFT:
        raise HttpError(409, "Already sent")
    _require(user, rules.CREATE)
    now = timezone.now()
    letter.status, letter.sent_at = Letter.IN_SIGNING, now
    if letter.publish_mode == "now":
        letter.shown_at = now
    letter.save(update_fields=["status", "sent_at", "shown_at"])
    audit(user, "letter_sent", str(letter.id), no=letter.no, signers=letter.participants.filter(role="signer").count())
    events.emit(letter, "sent", user)
    signing.notify_next(letter, "Letter to sign")
    if letter.shown_at:
        signing.notify_viewers(letter, "New letter")
    return _brief(user, letter)


# --- read ------------------------------------------------------------------------------------------------------


@router.get("", response=list[LetterBrief])
def list_letters(request, limit: int = 100, offset: int = 0, q: str = "", box: str = "all"):
    """Everything this user may see, newest first (`box=all`, the default), or one box: inbox, outbox, archive."""
    inbox.check_box(box)
    user = user_of(request)
    rows = inbox.box_of(user, rules.visible_letters(user), box).order_by("-no")
    if q:
        rows = rows.filter(title__icontains=q)  # use /letters/search for numbers, people, labels and body text
    return briefs.briefs(user, inbox.paged(rows, limit, offset))


class DirectoryUser(Schema):
    id: int
    email: str
    full_name: str
    title: str
    status_text: str
    permissions: list[str]


@router.get("/directory", response=list[DirectoryUser])
def directory(request):
    """Active colleagues, for picking signers and viewers when writing a letter."""
    users = User.objects.filter(is_active=True).select_related("org_title").prefetch_related("grants").order_by("email")
    return [DirectoryUser(id=u.id, email=u.email, full_name=u.full_name, status_text=u.status_text,
                          title=u.org_title.name if u.org_title_id else "",
                          permissions=sorted(g.code for g in u.grants.all())) for u in users]


@router.get("/events", response=list[dict])
def catch_up(request, after: int = 0):
    return replay_events(user_of(request), after)


def replay_events(user: User, after: int) -> list[dict]:
    visible = rules.visible_letters(user).values("pk")
    rows = LetterEvent.objects.filter(id__gt=after, letter__in=visible).select_related("letter").order_by("id")[:500]
    return [events.event_payload(ev, ev.letter) for ev in rows]


@router.get("/admin", response=list[AdminLetterOut])
def admin_list(request, limit: int = 100, offset: int = 0):
    """Manager view: title, status and participants only. No body, no wraps, no signatures' notes."""
    manager = require_manager(request)
    offset, limit = max(offset, 0), max(min(limit, 200), 0)
    rows = Letter.objects.exclude(status=Letter.DRAFT).select_related("creator").order_by("-no")[offset : offset + limit]
    return [AdminLetterOut(**_brief(manager, x).dict(), creator_email=x.creator.email, participants=_participants(x)) for x in rows]


@router.get("/seal-key", response=dict)
def seal_key(request):
    """Public half of the Ed25519 seal key; every signature's `seal` verifies against it."""
    user_of(request)
    return cryptoutil.seal_public_info()


def _signature_out(sig) -> SignatureOut:
    return SignatureOut(signer_id=sig.signer_id, decision=sig.decision, note=sig.payload.get("note", ""),
                        method=sig.method, device_name=sig.payload.get("deviceName", ""),
                        signed_at=str(sig.payload.get("signedAt", "")), seal=sig.seal, payload=sig.payload)


def _decrypted_body(letter: Letter) -> dict:
    try:
        return cryptoutil.decrypt_body(letter.body)
    except cryptoutil.DecryptError as exc:
        logger.error("Letter %s cannot be decrypted: %s", letter.id, exc)
        raise HttpError(500, "Letter cannot be decrypted; check DJANGO_DATA_KEY") from exc


@router.get("/{uuid:letter_id}", response=LetterOut)
def get_letter(request, letter_id: UUID):
    user = user_of(request)
    letter = _get_visible(user, letter_id)
    children = rules.visible_letters(user).filter(parent=letter).order_by("no")
    return LetterOut(
        **_brief(user, letter).dict(), publish_mode=letter.publish_mode, order=letter.order, due_at=letter.due_at,
        body=_decrypted_body(letter), participants=_participants(letter),
        signatures=[_signature_out(s) for s in letter.signatures.order_by("id")],
        children=briefs.briefs(user, children),
        attachments=[AttachmentOut(id=a.id, content_type=a.content_type, label=a.label, size=a.size)
                     for a in letter.attachments.order_by("created_at")],
        paraphs=paraphs.paraphs_of(letter), tasks=task_links.linked(user, letter),
        customer_refs=secretariat.customer_refs(letter.subject_id),
    )


@router.get("/{uuid:letter_id}/certificate", response=dict)
def certificate(request, letter_id: UUID):
    """Signature certificate: who signed which content, how and from which device, re-verified now (seal and
    content hash). The signed payloads are included so they can be re-checked against the published seal key."""
    letter = _get_visible(user_of(request), letter_id)
    current_hash = cryptoutil.content_hash(_decrypted_body(letter))
    sigs = []
    for s in letter.signatures.select_related("signer").order_by("id"):
        sigs.append({
            "signer": s.signer.email, "method": s.method, "device": s.payload.get("deviceName", ""),
            "decision": s.decision, "signed_at": s.payload.get("signedAt"), "payload": s.payload, "seal": s.seal,
            "verified": cryptoutil.verify_seal(s.payload, s.seal) and s.payload.get("contentHash") == current_hash,
        })
    paraph_rows = paraphs.certificate_rows(letter, current_hash)
    return {"letter": {"id": str(letter.id), "no": letter.no, "title": letter.title, "status": letter.status,
                       "creator": letter.creator.email, "sent_at": letter.sent_at, "closed_at": letter.closed_at,
                       "content_hash": current_hash},
            "seal_key": cryptoutil.seal_public_info(),
            "signatures": sigs, "all_verified": bool(sigs) and all(x["verified"] for x in sigs),
            "paraphs": paraph_rows, "paraphs_verified": all(x["verified"] for x in paraph_rows)}


@router.post("/{uuid:letter_id}/opened", response=Detail)
def mark_opened(request, letter_id: UUID):
    user = user_of(request)
    letter = _get_visible(user, letter_id)
    row = letter.participants.filter(user=user, role=Participant.SIGNER, opened_at__isnull=True).first()
    if row:
        row.opened_at = timezone.now()
        row.save(update_fields=["opened_at"])
        events.emit(letter, "opened", user)
    return {"detail": "ok"}


# --- sign ------------------------------------------------------------------------------------------------------


@transaction.atomic
def _sign_locked(letter_id: UUID, user: User, session, data: SignBiometricIn, method: str) -> Letter:
    _get_visible(user, letter_id)  # missing and invisible letters are both 404
    letter = get_object_or_404(Letter.objects.select_for_update(), pk=letter_id)
    signing.record_signature(letter, user, session, decision=data.decision, note=data.note, method=method)
    return letter


@router.post("/{uuid:letter_id}/sign", response=LetterBrief)
def sign_letter(request, letter_id: UUID, data: SignPinIn):
    """Sign with the signing PIN. Not atomic as a whole: a wrong PIN must keep its failure count and audit row."""
    user = user_of(request)
    signing.require_turn(_get_visible(user, letter_id), user)  # non-signers cannot burn PIN attempts
    signing.check_pin(user, data.pin, request.auth)
    return _brief(user, _sign_locked(letter_id, user, request.auth, data, "pin"))


@router.post("/{uuid:letter_id}/sign-biometric", response=LetterBrief)
def sign_biometric(request, letter_id: UUID, data: SignBiometricIn):
    """Sign after the app confirmed fingerprint/face locally. Only sessions created as biometric may."""
    user = user_of(request)
    if not request.auth.biometric:
        raise HttpError(403, "This session has no biometrics")
    return _brief(user, _sign_locked(letter_id, user, request.auth, data, "biometric"))


@router.post("/{uuid:letter_id}/sign-requests", response={201: SignRequestOut})
@transaction.atomic
def new_sign_request(request, letter_id: UUID, data: SignRequestIn):
    sr = create_request(letter_id, user_of(request), request.auth, data)
    return 201, request_out(sr)


# --- cancel / unlist -----------------------------------------------------------------------------------------


@router.post("/{uuid:letter_id}/cancel", response=LetterBrief)
@transaction.atomic
def cancel_letter(request, letter_id: UUID):
    user = user_of(request)
    letter = get_object_or_404(Letter.objects.select_for_update(), pk=letter_id, creator=user)
    if letter.status not in (Letter.DRAFT, Letter.IN_SIGNING):
        raise HttpError(409, f"Letter is {letter.status}")
    was_draft = letter.status == Letter.DRAFT
    letter.status, letter.closed_at = Letter.CANCELLED, timezone.now()
    letter.save(update_fields=["status", "closed_at"])
    audit(user, "letter_cancelled", str(letter.id))
    if not was_draft:
        events.emit(letter, "cancelled", user)
    return _brief(user, letter)


class UnlistIn(Schema):
    unlisted: bool = True


@router.post("/{uuid:letter_id}/unlist", response=LetterBrief)
@transaction.atomic
def unlist(request, letter_id: UUID, data: UnlistIn):
    """Manager only, published letters only. Reversible, audited; the letter itself is untouched."""
    manager = require_manager(request)
    letter = get_object_or_404(Letter.objects.select_for_update(), pk=letter_id)
    if letter.status != Letter.PUBLISHED:
        raise HttpError(409, "Only a published letter can be unlisted")
    letter.unlisted = data.unlisted
    letter.save(update_fields=["unlisted"])
    audit(manager, "letter_unlisted" if data.unlisted else "letter_relisted", str(letter.id))  # no titles in audit: the superuser reads the audit log
    events.emit(letter, "unlisted" if data.unlisted else "relisted", manager)
    return _brief(manager, letter)


# --- attachments -----------------------------------------------------------------------------------------------


@router.post("/{uuid:letter_id}/attachments", response={201: AttachmentOut})
@transaction.atomic
def add_attachment(request, letter_id: UUID, content_type: Form[str], label: Form[str] = "",
                   file: File[UploadedFile] = ...):
    user = user_of(request)
    letter = _lock_own_draft(user, letter_id, "A sent letter is immutable")
    if letter.attachments.count() >= MAX_ATTACHMENTS:
        raise HttpError(422, "Too many attachments on this letter")
    if content_type not in ATTACHMENT_TYPES:
        raise HttpError(422, "Only PDF and images are allowed")
    if file.size > settings.MAX_ATTACHMENT_BYTES:
        raise HttpError(413, "Attachment is larger than 25 MB")
    att = Attachment(letter=letter, content_type=content_type, label=label[:100], size=file.size)
    filestore.save_encrypted(att.file, file.read())
    att.save()
    return 201, AttachmentOut(id=att.id, content_type=att.content_type, label=att.label, size=att.size)


@router.get("/{uuid:letter_id}/attachments/{uuid:attachment_id}", response=None)
def download_attachment(request, letter_id: UUID, attachment_id: UUID):
    letter = _get_visible(user_of(request), letter_id)
    att = get_object_or_404(Attachment, pk=attachment_id, letter=letter)
    try:
        plain = filestore.read_decrypted(att.file)
    except filestore.DecryptError as exc:
        logger.error("Attachment %s cannot be decrypted: %s", att.id, exc)
        raise HttpError(500, "Attachment cannot be decrypted; check DJANGO_DATA_KEY") from exc
    return HttpResponse(plain, content_type=att.content_type)


# Letters v2 sub-routers (same prefix); kept in their own modules so this file stays small.
from .api_inbox import router as _inbox_router  # noqa: E402
from .api_links import router as _links_router  # noqa: E402
from .api_referrals import router as _referrals_router  # noqa: E402

for _sub in (_inbox_router, _referrals_router, _links_router):
    router.add_router("", _sub)
