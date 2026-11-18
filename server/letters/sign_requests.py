"""Remote biometric approval: a session without biometrics asks another biometric session of the same user."""
from datetime import timedelta
from uuid import UUID

from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja import Router
from ninja.errors import HttpError

from accounts.auth import BearerAuth, user_of
from accounts.models import Session, User, audit
from accounts.notify import push_session

from . import rules, signing
from .models import Letter, SignRequest
from .schemas import SignRequestIn, SignRequestOut

router = Router(tags=["sign-requests"], auth=BearerAuth())
REQUEST_TTL = timedelta(minutes=5)


def effective_status(sr: SignRequest) -> str:
    if sr.status == SignRequest.PENDING and sr.expires_at <= timezone.now():
        return SignRequest.EXPIRED
    return sr.status


def request_out(sr: SignRequest) -> SignRequestOut:
    return SignRequestOut(
        id=sr.id, letter_id=sr.letter_id, letter_title=sr.letter.title, decision=sr.decision, note=sr.note,
        status=effective_status(sr), requester_session_id=sr.requester_session_id,
        requester_device_name=sr.requester_session.device_name, approver_session_id=sr.approver_session_id,
        created_at=sr.created_at, expires_at=sr.expires_at, resolved_at=sr.resolved_at,
    )


def _push_after_commit(sr: SignRequest, *, frame: str, to: tuple) -> None:
    event = {"type": frame, "request": request_out(sr).model_dump(mode="json")}
    transaction.on_commit(lambda: [push_session(sid, event) for sid in to])


def _both(sr: SignRequest) -> tuple:
    return (sr.requester_session_id, sr.approver_session_id)


# --- create (called by POST /letters/{id}/sign-requests) ----------------------------------------------------


def create_request(letter_id: UUID, user: User, session: Session, data: SignRequestIn) -> SignRequest:
    if not rules.can_see(user, get_object_or_404(Letter, pk=letter_id)):
        raise HttpError(404, "Letter not found")
    letter = get_object_or_404(Letter.objects.select_for_update(), pk=letter_id)
    signing.require_turn(letter, user)
    approver = Session.objects.filter(pk=data.approver_session_id, user=user, revoked_at__isnull=True,
                                      biometric=True).exclude(pk=session.pk).first()
    if approver is None:
        raise HttpError(422, "Approver must be another signed-in biometric session of yours")
    for old in SignRequest.objects.filter(letter=letter, user=user, status=SignRequest.PENDING):
        _resolve(old, SignRequest.CANCELLED)
        _push_after_commit(old, frame="sign_request_update", to=_both(old))
    now = timezone.now()
    sr = SignRequest.objects.create(
        letter=letter, user=user, requester_session=session, approver_session=approver, decision=data.decision,
        note=data.note, created_at=now, expires_at=now + REQUEST_TTL)
    audit(user, "sign_requested", str(letter.id), decision=data.decision, request=str(sr.id),
          approver=str(approver.id), requester=str(session.id))
    _push_after_commit(sr, frame="sign_request", to=(approver.id,))
    return sr


def _resolve(sr: SignRequest, status: str) -> None:
    sr.status, sr.resolved_at = status, timezone.now()
    sr.save(update_fields=["status", "resolved_at"])


# --- the approver / requester side ---------------------------------------------------------------------------


def _own_request(user: User, rid: UUID) -> SignRequest:
    return get_object_or_404(SignRequest.objects.select_related("letter", "requester_session"), pk=rid, user=user)


def _lock_pending(user: User, rid: UUID) -> SignRequest:
    """Lock order is always Letter, then SignRequest. Status and expiry are checked AFTER the locks."""
    sr = _own_request(user, rid)
    Letter.objects.select_for_update().get(pk=sr.letter_id)
    sr = get_object_or_404(SignRequest.objects.select_for_update().select_related("letter", "requester_session"),
                           pk=rid, user=user)
    _require_pending(sr)
    return sr


def _require_pending(sr: SignRequest) -> None:
    status = effective_status(sr)
    if status != SignRequest.PENDING:
        raise HttpError(409, f"Request is {status}")


@router.get("/incoming", response=list[SignRequestOut])
def incoming(request):
    rows = SignRequest.objects.filter(
        user=user_of(request), approver_session=request.auth, status=SignRequest.PENDING, expires_at__gt=timezone.now()
    ).select_related("letter", "requester_session").order_by("created_at")
    return [request_out(sr) for sr in rows]


@router.get("/{uuid:rid}", response=SignRequestOut)
def get_request(request, rid: UUID):
    return request_out(_own_request(user_of(request), rid))


@router.post("/{uuid:rid}/approve", response=SignRequestOut)
@transaction.atomic
def approve(request, rid: UUID):
    user, session = user_of(request), request.auth
    sr = _own_request(user, rid)
    if sr.approver_session_id != session.id:
        raise HttpError(403, "Only the approving session can approve")
    if not session.biometric:
        raise HttpError(403, "This session has no biometrics")
    sr = _lock_pending(user, rid)
    letter = sr.letter
    signing.record_signature(letter, user, session, decision=sr.decision, note=sr.note, method="biometric")
    _resolve(sr, SignRequest.APPROVED)
    _push_after_commit(sr, frame="sign_request_update", to=_both(sr))
    return request_out(sr)


@router.post("/{uuid:rid}/decline", response=SignRequestOut)
@transaction.atomic
def decline(request, rid: UUID):
    user, session = user_of(request), request.auth
    sr = _own_request(user, rid)
    if sr.approver_session_id != session.id:
        raise HttpError(403, "Only the approving session can decline")
    sr = _lock_pending(user, rid)
    _resolve(sr, SignRequest.DECLINED)
    audit(user, "sign_request_declined", str(sr.letter_id), request=str(sr.id), session=str(session.id))
    _push_after_commit(sr, frame="sign_request_update", to=_both(sr))
    return request_out(sr)


@router.post("/{uuid:rid}/cancel", response=SignRequestOut)
@transaction.atomic
def cancel(request, rid: UUID):
    user, session = user_of(request), request.auth
    sr = _own_request(user, rid)
    if sr.requester_session_id != session.id:
        raise HttpError(403, "Only the requesting session can cancel")
    sr = _lock_pending(user, rid)
    _resolve(sr, SignRequest.CANCELLED)
    _push_after_commit(sr, frame="sign_request_update", to=_both(sr))
    return request_out(sr)
