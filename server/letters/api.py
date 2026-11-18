"""Letters: create/send/sign/publish, visibility, unlist, attachments, history. The server never sees a body."""
import json
from datetime import datetime, timedelta
from uuid import UUID

from django.conf import settings
from django.db import IntegrityError, transaction
from django.db.models import Max
from django.http import FileResponse
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja import File, Form, Router, Schema
from ninja.errors import HttpError
from ninja.files import UploadedFile

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, require_manager, user_of
from accounts.models import User, audit
from accounts.notify import notify
from core import cryptoutil
from keys.api import KeyOut
from keys.models import CompanyKeyVersion, UserKey

from . import events, rules
from .models import Attachment, DocKeyWrap, Letter, LetterEvent, Participant, Signature
from .schemas import (AdminLetterOut, AttachmentOut, LetterBrief, LetterIn, LetterOut, ParticipantOut, SignatureOut,
                      SignIn, WrapIn)

router = Router(tags=["letters"], auth=BearerAuth())
SIGN_SKEW = timedelta(minutes=10)
MAX_WRAPS, MAX_PEOPLE, MAX_JSON_BYTES, MAX_BODY_CHARS, MAX_ATTACHMENTS = 500, 500, 8192, 2_000_000, 20
ATTACHMENT_TYPES = {"application/pdf", "image/png", "image/jpeg", "image/webp", "image/heic"}
DECISIONS = {"approved", "rejected"}


def _brief(letter: Letter) -> LetterBrief:
    return LetterBrief.from_orm(letter)


def _participants(letter: Letter) -> list[ParticipantOut]:
    rows = letter.participants.exclude(role="removed").select_related("user").order_by("role", "position", "id")
    return [ParticipantOut(user_id=p.user_id, email=p.user.email, full_name=p.user.full_name, role=p.role,
                           position=p.position, decision=p.decision, decided_at=p.decided_at) for p in rows]


def _get_visible(user: User, letter_id: UUID) -> Letter:
    letter = get_object_or_404(Letter, pk=letter_id)
    if not rules.can_see(user, letter):
        raise HttpError(404, "Letter not found")
    return letter


def _get_own_draft_or_sent(user: User, letter_id: UUID) -> Letter:
    letter = get_object_or_404(Letter, pk=letter_id, creator=user)
    return letter


def _require(user: User, code: str) -> None:
    if code not in rules.grants_of(user):
        raise HttpError(403, "Permission denied")


# --- create / edit draft -------------------------------------------------------------------------------------


def _apply(letter: Letter, user: User, data: LetterIn) -> None:
    """Validates and stores everything for a draft (new or replaced)."""
    if not isinstance(data.body.get("iv"), str) or not isinstance(data.body.get("ct"), str) or set(data.body) != {"iv", "ct"}:
        raise HttpError(422, "body must be {iv, ct}")
    if len(data.body["ct"]) > MAX_BODY_CHARS or len(data.body["iv"]) > 64:
        raise HttpError(413, "body is too large")
    if len(data.signer_ids) > MAX_PEOPLE or len(data.viewer_ids) > MAX_PEOPLE:
        raise HttpError(422, "Too many participants")
    _check_size(data.company_wrap, "company_wrap")
    signer_ids = list(dict.fromkeys(data.signer_ids))
    viewer_ids = [v for v in dict.fromkeys(data.viewer_ids) if v not in signer_ids and v != user.id]
    if data.visibility == "public" and data.viewer_ids:
        raise HttpError(422, "Public letters have no viewer list")
    if data.visibility == "public" and (data.company_key_version is None or data.company_wrap is None):
        raise HttpError(422, "Public letters need the document key wrapped under the company key")
    if data.visibility == "private" and data.company_wrap is not None:
        raise HttpError(422, "Private letters must not carry a company wrap")
    if data.company_key_version and not CompanyKeyVersion.objects.filter(version=data.company_key_version).exists():
        raise HttpError(422, "Unknown company key version")
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
    letter.title, letter.body = data.title.strip(), data.body
    letter.visibility, letter.publish_mode, letter.order = data.visibility, data.publish_mode, data.order
    letter.due_at, letter.company_key_version, letter.company_wrap = data.due_at, data.company_key_version, data.company_wrap
    letter.save()
    # Nothing is deleted: people dropped from the draft keep a row with role "removed" (ignored everywhere).
    Participant.objects.filter(letter=letter).update(role="removed")
    for pos, uid in enumerate(signer_ids):
        Participant.objects.update_or_create(letter=letter, user=people[uid], defaults={
            "role": Participant.SIGNER, "position": pos, "decision": ""})
    for uid in viewer_ids:
        Participant.objects.update_or_create(letter=letter, user=people[uid], defaults={
            "role": Participant.VIEWER, "position": 0, "decision": ""})
    _store_wraps(letter, data.wraps, writer=user)


def _store_wraps(letter: Letter, wraps: list[WrapIn], *, writer: User) -> None:
    """The creator (on a draft) and a key's own owner may replace its wrap (so a poisoned wrap can be repaired);
    anyone else can only fill a missing one, never overwrite."""
    allowed = {k.id: k for k in rules.required_keys(letter)}
    ids = [w.key_id for w in wraps]
    if len(ids) > MAX_WRAPS or len(set(ids)) != len(ids) or set(ids) - allowed.keys():
        raise HttpError(422, "Wraps may only target distinct active keys of people who can read this letter")
    for w in wraps:
        _check_size(w.wrap, "wrap")
        may_replace = allowed[w.key_id].user_id == writer.id or (
            letter.status == Letter.DRAFT and letter.creator_id == writer.id)
        if may_replace:
            DocKeyWrap.objects.update_or_create(letter=letter, key_id=w.key_id, defaults={"wrap": w.wrap})
        else:
            DocKeyWrap.objects.get_or_create(letter=letter, key_id=w.key_id, defaults={"wrap": w.wrap})


def _check_size(value, what: str) -> None:
    if len(json.dumps(value)) > MAX_JSON_BYTES:
        raise HttpError(413, f"{what} is too large")


@router.post("", response={201: LetterBrief})
@transaction.atomic
def create_letter(request, data: LetterIn):
    user = user_of(request)
    _require(user, rules.CREATE)
    letter = Letter(creator=user, no=(Letter.objects.aggregate(m=Max("no"))["m"] or 0) + 1, body=data.body,
                    title=data.title, visibility=data.visibility, publish_mode=data.publish_mode, order=data.order)
    letter.save()
    _apply(letter, user, data)
    audit(user, "letter_created", str(letter.id), no=letter.no)
    return 201, _brief(letter)


@router.put("/{uuid:letter_id}", response=LetterBrief)
@transaction.atomic
def update_draft(request, letter_id: UUID, data: LetterIn):
    user = user_of(request)
    letter = _get_own_draft_or_sent(user, letter_id)
    if letter.status != Letter.DRAFT:
        raise HttpError(409, "A sent letter is immutable; write a new chained letter")
    _apply(letter, user, data)
    return _brief(letter)


# --- send ------------------------------------------------------------------------------------------------------


def missing_wraps(letter: Letter) -> list[UUID]:
    have = set(letter.wraps.values_list("key_id", flat=True))
    return [k.id for k in rules.required_keys(letter) if k.id not in have]


@router.post("/{uuid:letter_id}/send", response=LetterBrief)
@transaction.atomic
def send_letter(request, letter_id: UUID):
    user = user_of(request)
    letter = get_object_or_404(Letter.objects.select_for_update(), pk=letter_id, creator=user)
    if letter.status != Letter.DRAFT:
        raise HttpError(409, "Already sent")
    _require(user, rules.CREATE)
    missing = missing_wraps(letter)
    if missing:  # a key was approved since the draft was made: the app adds wraps and retries
        raise HttpError(409, "Missing document-key wraps for: " + ", ".join(map(str, missing)))
    now = timezone.now()
    letter.status, letter.sent_at = Letter.IN_SIGNING, now
    if letter.publish_mode == "now":
        letter.shown_at = now
    letter.save(update_fields=["status", "sent_at", "shown_at"])
    audit(user, "letter_sent", str(letter.id), no=letter.no, signers=letter.participants.filter(role="signer").count())
    events.emit(letter, "sent", user)
    _notify_next(letter, "Letter to sign")
    if letter.shown_at:
        _notify_viewers(letter, "New letter")
    return _brief(letter)


def _notify_next(letter: Letter, prefix: str) -> None:
    users = User.objects.filter(pk__in=rules.next_signer_ids(letter))
    notify(users, "sign_request", f"{prefix}: {letter.title}", letter_id=str(letter.id))


def _notify_viewers(letter: Letter, prefix: str) -> None:
    if letter.unlisted:
        return
    ids = rules.audience_ids(letter) - {letter.creator_id} - set(
        letter.participants.filter(role="signer").values_list("user_id", flat=True))
    notify(User.objects.filter(pk__in=ids), "letter_published", f"{prefix}: {letter.title}", letter_id=str(letter.id))


# --- read ------------------------------------------------------------------------------------------------------


@router.get("", response=list[LetterBrief])
def list_letters(request, limit: int = 100, offset: int = 0, q: str = ""):
    """Everything this user may see, newest first: this is also the history, identical on every device."""
    offset, limit = max(offset, 0), max(min(limit, 200), 0)
    qs = rules.visible_letters(user_of(request)).order_by("-no")
    if q:
        qs = qs.filter(title__icontains=q)  # titles are the only searchable text
    return [_brief(x) for x in qs[offset : offset + limit]]


@router.get("/events", response=list[dict])
def catch_up(request, after: int = 0):
    return replay_events(user_of(request), after)


def replay_events(user: User, after: int) -> list[dict]:
    visible = rules.visible_letters(user).values("pk")
    rows = LetterEvent.objects.filter(id__gt=after, letter__in=visible).select_related("letter").order_by("id")[:500]
    return [events.event_payload(ev, ev.letter) for ev in rows]


@router.get("/rewrap-needed", response=list[dict])
def rewrap_needed(request):
    """Letters this user can read where some participant key lacks a wrapped document key (new device approved)."""
    user = user_of(request)
    mine = set(UserKey.objects.filter(user=user, status=UserKey.ACTIVE).values_list("id", flat=True))
    letters = Letter.objects.filter(wraps__key_id__in=mine).exclude(status=Letter.DRAFT).distinct()[:200]
    out = []
    for letter in letters:
        have = set(letter.wraps.values_list("key_id", flat=True))
        out += [{"letter_id": str(letter.id), "key": KeyOut.of(k).dict()} for k in rules.required_keys(letter)
                if k.id not in have]
    return out


@router.get("/admin", response=list[AdminLetterOut])
def admin_list(request, limit: int = 100, offset: int = 0):
    """Manager view: title, status and participants only. No body, no wraps, no signatures' notes."""
    require_manager(request)
    offset, limit = max(offset, 0), max(min(limit, 200), 0)
    rows = Letter.objects.exclude(status=Letter.DRAFT).select_related("creator").order_by("-no")[offset : offset + limit]
    return [AdminLetterOut(**_brief(x).dict(), creator_email=x.creator.email, participants=_participants(x)) for x in rows]


@router.get("/{uuid:letter_id}", response=LetterOut)
def get_letter(request, letter_id: UUID):
    user = user_of(request)
    letter = _get_visible(user, letter_id)
    mine = DocKeyWrap.objects.filter(letter=letter, key__user=user, key__status=UserKey.ACTIVE)
    children = rules.visible_letters(user).filter(parent=letter).order_by("no")
    sigs = letter.signatures.select_related("key").order_by("id")
    return LetterOut(
        **_brief(letter).dict(), publish_mode=letter.publish_mode, order=letter.order, due_at=letter.due_at,
        body=letter.body, company_key_version=letter.company_key_version, company_wrap=letter.company_wrap,
        participants=_participants(letter),
        signatures=[SignatureOut(signer_id=s.signer_id, key_id=s.key_id, fingerprint=s.key.fingerprint,
                                 decision=s.decision, payload=s.payload, signature=s.signature,
                                 created_at=s.created_at) for s in sigs],
        my_wraps=[WrapIn(key_id=w.key_id, wrap=w.wrap) for w in mine],
        children=[_brief(c) for c in children],
        attachments=[AttachmentOut(id=a.id, content_type=a.content_type, label=a.label, iv=a.iv, size=a.size)
                     for a in letter.attachments.order_by("created_at")],
    )


@router.get("/{uuid:letter_id}/certificate", response=dict)
def certificate(request, letter_id: UUID):
    """Signature certificate: who signed which content with which key from which device, re-verified now.
    The signed payloads are included so anyone can re-check them offline against the public keys."""
    letter = _get_visible(user_of(request), letter_id)
    sigs = []
    for s in letter.signatures.select_related("key", "signer").order_by("id"):
        sigs.append({
            "signer": s.signer.email, "fingerprint": s.key.fingerprint, "device": s.payload.get("deviceName", ""),
            "decision": s.decision, "signed_at": s.payload.get("signedAt"), "payload": s.payload,
            "signature": s.signature, "sign_pub": s.key.sign_pub,
            "verified": cryptoutil.verify_ecdsa(s.payload, s.signature, s.key.sign_pub)
            and s.payload.get("contentHash") == cryptoutil.content_hash(letter.body),
        })
    return {"letter": {"id": str(letter.id), "no": letter.no, "title": letter.title, "status": letter.status,
                       "creator": letter.creator.email, "sent_at": letter.sent_at, "closed_at": letter.closed_at,
                       "content_hash": cryptoutil.content_hash(letter.body)},
            "signatures": sigs, "all_verified": all(x["verified"] for x in sigs)}


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


@router.post("/{uuid:letter_id}/wraps", response=Detail)
@transaction.atomic
def add_wraps(request, letter_id: UUID, wraps: list[WrapIn]):
    """Re-wrap the document key for newly approved keys. Only someone who can already read it may do this,
    and existing wraps are never overwritten."""
    user = user_of(request)
    letter = _get_visible(user, letter_id)
    if not DocKeyWrap.objects.filter(letter=letter, key__user=user, key__status=UserKey.ACTIVE).exists() \
            and letter.status != Letter.DRAFT:
        raise HttpError(403, "You do not hold this letter's document key")
    _store_wraps(letter, wraps, writer=user)
    audit(user, "letter_rewrapped", str(letter.id), count=len(wraps))
    return {"detail": "Stored"}


# --- sign ------------------------------------------------------------------------------------------------------


def _check_payload(payload: dict, letter: Letter, user: User, key: UserKey, session) -> None:
    signer = payload.get("signer") or {}
    expected = {
        "letterId": str(letter.id), "title": letter.title, "decision": payload.get("decision"),
        "contentHash": cryptoutil.content_hash(letter.body),
        "parentId": str(letter.parent_id) if letter.parent_id else None,
    }
    if any(payload.get(k) != v for k, v in expected.items()) or payload.get("decision") not in DECISIONS:
        raise HttpError(422, "Payload does not match this letter")
    if signer != {"userId": user.id, "keyId": str(key.id), "fp": key.fingerprint}:
        raise HttpError(422, "Payload signer does not match your key")
    if payload.get("sessionId") != str(session.id):
        raise HttpError(422, "Payload was signed for another session")
    nonce = payload.get("nonce")
    if not isinstance(nonce, str) or not 16 <= len(nonce) <= 64:
        raise HttpError(422, "Bad nonce")
    note = payload.get("note", "")
    if not isinstance(note, str) or len(note) > 2000:
        raise HttpError(422, "Bad note")
    try:
        signed_at = datetime.fromisoformat(str(payload.get("signedAt")).replace("Z", "+00:00"))
    except ValueError as exc:
        raise HttpError(422, "Bad signedAt") from exc
    if signed_at.tzinfo is None or abs(timezone.now() - signed_at) > SIGN_SKEW:
        raise HttpError(422, "signedAt is too far from server time")


@router.post("/{uuid:letter_id}/sign", response=LetterBrief)
@transaction.atomic
def sign_letter(request, letter_id: UUID, data: SignIn):
    user = user_of(request)
    letter = get_object_or_404(Letter.objects.select_for_update(), pk=letter_id)
    me = letter.participants.filter(user=user, role=Participant.SIGNER).first()
    if me is None:
        raise HttpError(403, "You are not a signer of this letter")
    if letter.status != Letter.IN_SIGNING:
        raise HttpError(409, f"Letter is {letter.status}")
    if me.decision:
        raise HttpError(409, "You already decided")
    if user.id not in rules.next_signer_ids(letter):
        raise HttpError(409, "It is not your turn yet")
    key = UserKey.objects.filter(pk=data.key_id, user=user, status=UserKey.ACTIVE).first()
    if key is None:
        raise HttpError(403, "Key is not active")
    if not DocKeyWrap.objects.filter(letter=letter, key=key).exists():
        raise HttpError(403, "This key cannot read the letter yet")  # pending/new keys cannot sign
    _check_size(data.payload, "payload")
    _check_payload(data.payload, letter, user, key, request.auth)
    if not cryptoutil.verify_ecdsa(data.payload, data.signature, key.sign_pub):
        raise HttpError(422, "Signature does not verify")
    decision, now = data.payload["decision"], timezone.now()
    try:
        with transaction.atomic():
            Signature.objects.create(letter=letter, signer=user, key=key, decision=decision, payload=data.payload,
                                     signature=data.signature, nonce=data.payload["nonce"])
    except IntegrityError as exc:
        raise HttpError(409, "Replayed signature") from exc
    me.decision, me.decided_at = decision, now
    me.save(update_fields=["decision", "decided_at"])
    audit(user, "letter_signed", str(letter.id), decision=decision, key=str(key.id), fingerprint=key.fingerprint,
          session=str(request.auth.id), device=request.auth.device_name)
    events.emit(letter, "signed" if decision == "approved" else "rejected", user, decision=decision)
    _advance(letter, user, decision, now)
    return _brief(letter)


def _advance(letter: Letter, actor: User, decision: str, now) -> None:
    if decision == "rejected":  # final: the creator may start a new chained letter
        letter.status, letter.closed_at = Letter.REJECTED, now
        letter.save(update_fields=["status", "closed_at"])
        people = User.objects.filter(pk__in={letter.creator_id, *letter.participants.filter(role="signer").values_list("user_id", flat=True)})
        notify(people, "letter_rejected", f"Rejected: {letter.title}", letter_id=str(letter.id))
        return
    if letter.participants.filter(role=Participant.SIGNER, decision="").exists():
        if letter.order == "serial":
            _notify_next(letter, "Your turn to sign")
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
    _notify_viewers(letter, "Published")


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
    return _brief(letter)


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
    return _brief(letter)


# --- attachments -----------------------------------------------------------------------------------------------


@router.post("/{uuid:letter_id}/attachments", response={201: AttachmentOut})
@transaction.atomic
def add_attachment(request, letter_id: UUID, content_type: Form[str], iv: Form[str], label: Form[str] = "",
                   file: File[UploadedFile] = ...):
    user = user_of(request)
    letter = _get_own_draft_or_sent(user, letter_id)
    if letter.status != Letter.DRAFT:
        raise HttpError(409, "A sent letter is immutable")
    if letter.attachments.count() >= MAX_ATTACHMENTS:
        raise HttpError(422, "Too many attachments on this letter")
    if content_type not in ATTACHMENT_TYPES:
        raise HttpError(422, "Only PDF and images are allowed")
    if file.size > settings.MAX_ATTACHMENT_BYTES:
        raise HttpError(413, "Attachment is larger than 25 MB")
    att = Attachment(letter=letter, content_type=content_type, label=label[:100], iv=iv[:32], size=file.size)
    att.file.save("blob", file, save=False)
    att.save()
    return 201, AttachmentOut(id=att.id, content_type=att.content_type, label=att.label, iv=att.iv, size=att.size)


@router.get("/{uuid:letter_id}/attachments/{uuid:attachment_id}", response=None)
def download_attachment(request, letter_id: UUID, attachment_id: UUID):
    letter = _get_visible(user_of(request), letter_id)
    att = get_object_or_404(Attachment, pk=attachment_id, letter=letter)
    return FileResponse(att.file.open("rb"), content_type="application/octet-stream")
