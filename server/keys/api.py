"""Public keys, the manager's approval queue, and the company group key. Private keys never reach the server."""
from uuid import UUID

from django.db import IntegrityError, transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja import Router, Schema
from ninja.errors import HttpError

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, require_manager, user_of
from accounts.models import AuditEvent, Session, User, audit
from accounts.notify import managers, notify
from core import cryptoutil

from .models import CompanyKeyVersion, CompanyKeyWrap, UserKey

router = Router(tags=["keys"], auth=BearerAuth())


class KeyIn(Schema):
    device_name: str = ""
    sign_pub: dict
    enc_pub: dict
    fingerprint: str | None = None


class KeyOut(Schema):
    id: UUID
    user_id: int
    device_name: str
    sign_pub: dict
    enc_pub: dict
    fingerprint: str
    status: str
    created_at: str
    approved_at: str | None = None

    @staticmethod
    def of(k: UserKey) -> "KeyOut":
        return KeyOut(
            id=k.id, user_id=k.user_id, device_name=k.device_name, sign_pub=k.sign_pub, enc_pub=k.enc_pub,
            fingerprint=k.fingerprint, status=k.status, created_at=k.created_at.isoformat(),
            approved_at=k.approved_at.isoformat() if k.approved_at else None,
        )


class TransferIn(Schema):
    kind: str  # "export" | "import"


class WrapIn(Schema):
    key_id: UUID
    wrap: dict


class CompanyKeyIn(Schema):
    version: int
    wraps: list[WrapIn]


def active_keys(user_ids=None):
    qs = UserKey.objects.filter(status=UserKey.ACTIVE, user__is_active=True)
    return qs.filter(user_id__in=user_ids) if user_ids is not None else qs


def key_alert(key: UserKey, what: str, actor: User) -> None:
    """Public-key change alert (roadmap 5.4a): the owner on all sessions, and the manager."""
    recipients = {key.user_id: key.user, **{m.id: m for m in managers()}}
    notify(recipients.values(), "key_change", f"Key {what}: {key.user.email} ({key.fingerprint})",
           key_id=str(key.id), fingerprint=key.fingerprint, by=actor.email)


@router.post("", response={201: KeyOut})
@transaction.atomic
def upload_key(request, data: KeyIn):
    user = user_of(request)
    try:
        sign_pub, enc_pub = cryptoutil.clean_jwk(data.sign_pub), cryptoutil.clean_jwk(data.enc_pub)
        fp = cryptoutil.fingerprint(sign_pub, enc_pub)
    except cryptoutil.BadKey as exc:
        raise HttpError(422, str(exc)) from exc
    if data.fingerprint and data.fingerprint != fp:
        raise HttpError(422, "Fingerprint does not match the public keys")
    first = not UserKey.objects.filter(user=user).exists()
    now = timezone.now()
    try:
        with transaction.atomic():
            key = UserKey.objects.create(
                user=user, device_name=data.device_name[:100], sign_pub=sign_pub, enc_pub=enc_pub, fingerprint=fp,
                status=UserKey.ACTIVE if first else UserKey.PENDING,
                approved_at=now if first else None,
            )
    except IntegrityError as exc:
        raise HttpError(409, "This key is already registered") from exc
    audit(user, "key_created", str(key.id), fingerprint=fp, status=key.status, session=str(request.auth.id))
    key_alert(key, "added" if first else "requested (pending approval)", user)
    return 201, KeyOut.of(key)


@router.get("/mine", response=list[KeyOut])
def my_keys(request):
    return [KeyOut.of(k) for k in UserKey.objects.filter(user=user_of(request)).order_by("created_at")]


class DirectoryUser(Schema):
    id: int
    email: str
    full_name: str
    permissions: list[str]
    keys: list[KeyOut]


@router.get("/directory", response=list[DirectoryUser])
def directory(request):
    """Active colleagues and their active public keys: what the app needs to wrap a document key."""
    by_user: dict[int, list[KeyOut]] = {}
    for k in active_keys():
        by_user.setdefault(k.user_id, []).append(KeyOut.of(k))
    users = User.objects.filter(is_active=True, pk__in=by_user).prefetch_related("grants").order_by("email")
    return [
        DirectoryUser(id=u.id, email=u.email, full_name=u.full_name,
                      permissions=sorted(g.code for g in u.grants.all()), keys=by_user[u.id])
        for u in users
    ]


@router.post("/{uuid:key_id}/retire", response=KeyOut)
@transaction.atomic
def retire_key(request, key_id: UUID):
    actor = user_of(request)
    key = get_object_or_404(UserKey.objects.select_related("user"), pk=key_id)
    if key.user_id != actor.id and not actor.is_manager:
        raise HttpError(403, "Not your key")
    if key.status == UserKey.RETIRED:
        raise HttpError(409, "Already retired")
    key.status, key.retired_at = UserKey.RETIRED, timezone.now()
    key.save(update_fields=["status", "retired_at"])
    audit(actor, "key_retired", str(key.id), fingerprint=key.fingerprint)
    key_alert(key, "retired", actor)
    return KeyOut.of(key)


@router.post("/{uuid:key_id}/transfer-event", response=Detail)
def transfer_event(request, key_id: UUID, data: TransferIn):
    """Password-protected keys move by QR/file on the device; the app reports it so it is audited and visible."""
    user = user_of(request)
    if data.kind not in ("export", "import"):
        raise HttpError(422, "kind must be export or import")
    key = get_object_or_404(UserKey, pk=key_id, user=user, status=UserKey.ACTIVE)
    audit(user, f"key_{data.kind}", str(key.id), fingerprint=key.fingerprint, session=str(request.auth.id))
    others = Session.objects.filter(user=user, revoked_at__isnull=True).exclude(pk=request.auth.pk).exists()
    if others:
        notify([user], "key_transfer", f"Key {data.kind} on {request.auth.device_name or 'a device'}", key_id=str(key.id))
    return {"detail": "Recorded"}


@router.get("/pending", response=list[KeyOut])
def pending(request):
    require_manager(request)
    return [KeyOut.of(k) for k in UserKey.objects.filter(status=UserKey.PENDING).order_by("created_at")]


@router.post("/{uuid:key_id}/approve", response=KeyOut)
@transaction.atomic
def approve(request, key_id: UUID):
    manager = require_manager(request)
    key = get_object_or_404(UserKey.objects.select_related("user"), pk=key_id, status=UserKey.PENDING)
    key.status, key.approved_by, key.approved_at = UserKey.ACTIVE, manager, timezone.now()
    key.save(update_fields=["status", "approved_by", "approved_at"])
    audit(manager, "key_approved", str(key.id), fingerprint=key.fingerprint, owner=key.user.email)
    key_alert(key, "approved", manager)
    return KeyOut.of(key)


class CompanyStatus(Schema):
    version: int
    needs_rotation: bool


def _latest_version() -> CompanyKeyVersion | None:
    return CompanyKeyVersion.objects.order_by("-version").first()


@router.get("/company/status", response=CompanyStatus)
def company_status(request):
    latest = _latest_version()
    if latest is None:
        return CompanyStatus(version=0, needs_rotation=False)
    left_since = AuditEvent.objects.filter(action="user_deactivated", at__gt=latest.created_at).exists()
    return CompanyStatus(version=latest.version, needs_rotation=left_since)


@router.post("/company", response=CompanyStatus)
@transaction.atomic
def set_company_key(request, data: CompanyKeyIn):
    """Manager's app uploads the company key wrapped per active key: a new version (rotation) or more wraps
    for the current version (new members/devices)."""
    manager = require_manager(request)
    latest = _latest_version()
    current = latest.version if latest else 0
    if data.version not in (current, current + 1) or data.version == 0:
        raise HttpError(409, f"Next version is {current + 1}")
    version = CompanyKeyVersion.objects.get_or_create(version=data.version, defaults={"created_by": manager})[0]
    ids = {w.key_id for w in data.wraps}
    keys = {k.id: k for k in active_keys().filter(id__in=ids)}
    if ids - keys.keys():
        raise HttpError(422, "Wraps may only target active keys")
    for w in data.wraps:
        CompanyKeyWrap.objects.update_or_create(version=version, key=keys[w.key_id], defaults={"wrap": w.wrap})
    audit(manager, "company_key_set", str(version.version), wraps=len(ids))
    return CompanyStatus(version=version.version, needs_rotation=False)


class CompanyWrapOut(Schema):
    version: int
    key_id: UUID
    wrap: dict


@router.get("/company/mine", response=list[CompanyWrapOut])
def my_company_wraps(request):
    rows = CompanyKeyWrap.objects.filter(key__user=user_of(request), key__status=UserKey.ACTIVE)
    return [CompanyWrapOut(version=w.version_id, key_id=w.key_id, wrap=w.wrap) for w in rows.order_by("version_id")]


@router.get("/company/missing", response=list[KeyOut])
def keys_missing_company_wrap(request):
    """Manager/members: active keys that still lack the latest company key (new members to onboard)."""
    require_manager(request)
    latest = _latest_version()
    if latest is None:
        return []
    have = CompanyKeyWrap.objects.filter(version=latest).values("key_id")
    return [KeyOut.of(k) for k in active_keys().exclude(id__in=have)]
