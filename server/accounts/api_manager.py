"""Company administration for the (single) manager. Nothing here deletes anything."""
from datetime import datetime

from django.core import signing
from django.shortcuts import get_object_or_404
from ninja import Router, Schema
from ninja.errors import HttpError

from . import mailer
from .api_auth import Detail
from .auth import BearerAuth, require_manager
from .models import BASE_PERMISSION, CompanySettings, InviteCode, Permission, Session, User, audit
from .schemas import UserOut
from django.utils import timezone

router = Router(tags=["manager"], auth=BearerAuth())


class PermissionOut(Schema):
    code: str
    description: str


class GrantsIn(Schema):
    codes: list[str]


class ActiveIn(Schema):
    active: bool


class TokenOut(Schema):
    token: str


LETTERHEAD_TEXT_FIELDS = ("name", "tagline", "address", "phone", "email", "website", "footer")
LETTERHEAD_MAX_TEXT = 300
LETTERHEAD_MAX_LOGO = 300_000  # characters of base64 (about 220 KB of image)
LETTERHEAD_LOGO_PREFIXES = ("data:image/png;base64,", "data:image/jpeg;base64,")


def clean_letterhead(raw: dict) -> dict:
    """Whitelist keys, trim text, accept only a small PNG/JPEG data URL as logo. Empty values are dropped."""
    out = {k: str(raw[k]).strip()[:LETTERHEAD_MAX_TEXT] for k in LETTERHEAD_TEXT_FIELDS if raw.get(k)}
    logo = raw.get("logo") or ""
    if logo:
        if not isinstance(logo, str) or not logo.startswith(LETTERHEAD_LOGO_PREFIXES) or len(logo) > LETTERHEAD_MAX_LOGO:
            raise HttpError(422, "Logo must be a PNG or JPEG under about 200 KB")
        out["logo"] = logo
    return {k: v for k, v in out.items() if v}


class CompanyOut(Schema):
    letterhead: dict
    signup_domain_enabled: bool
    allowed_domain: str
    signup_invite_enabled: bool
    email_configured: bool


class CompanyIn(Schema):
    signup_domain_enabled: bool | None = None
    allowed_domain: str | None = None
    signup_invite_enabled: bool | None = None
    letterhead: dict | None = None


class InviteIn(Schema):
    max_uses: int | None = 1  # null = unlimited
    expires_at: datetime | None = None


class InviteOut(Schema):
    id: int
    code: str
    max_uses: int | None
    uses: int
    expires_at: datetime | None
    active: bool


@router.get("/permissions", response=list[PermissionOut])
def permissions(request):
    require_manager(request)
    return Permission.objects.order_by("code")


@router.get("/users", response=list[UserOut])
def users(request):
    require_manager(request)
    return [UserOut.of(u) for u in User.objects.prefetch_related("grants").order_by("email")]


@router.put("/users/{user_id}/permissions", response=UserOut)
def set_permissions(request, user_id: int, data: GrantsIn):
    manager = require_manager(request)
    target = get_object_or_404(User, pk=user_id)
    if target.is_superuser and target.pk != manager.pk:  # the manager may grant themselves letter permissions
        raise HttpError(403, "This account cannot be changed here")
    codes = set(data.codes) | {BASE_PERMISSION}
    found = Permission.objects.filter(code__in=codes)
    if found.count() != len(codes):
        raise HttpError(422, "Unknown permission code")
    before = sorted(target.grants.values_list("code", flat=True))
    target.grants.set(found)
    audit(manager, "permissions_set", target.email, before=before, after=sorted(codes))
    return UserOut.of(target)


@router.post("/users/{user_id}/active", response=UserOut)
def set_active(request, user_id: int, data: ActiveIn):
    manager = require_manager(request)
    target = get_object_or_404(User, pk=user_id)
    if target.pk == manager.pk or target.is_superuser:
        raise HttpError(403, "This account cannot be changed here")
    target.is_active = data.active
    target.save(update_fields=["is_active"])
    if not data.active:
        Session.objects.filter(user=target, revoked_at__isnull=True).update(revoked_at=timezone.now())
    audit(manager, "user_activated" if data.active else "user_deactivated", target.email)
    return UserOut.of(target)


@router.post("/users/{user_id}/reset-token", response=TokenOut)
def reset_token(request, user_id: int):
    """For when email is not configured: the manager hands this token to the user."""
    manager = require_manager(request)
    target = get_object_or_404(User, pk=user_id, is_active=True)
    if target.is_superuser:
        raise HttpError(403, "This account cannot be changed here")
    token = signing.dumps({"u": target.id, "p": target.password[-16:]}, salt="password-reset")
    audit(manager, "reset_token_issued", target.email)
    return {"token": token}


def _company_out(cs: CompanySettings) -> CompanyOut:
    return CompanyOut(
        letterhead=cs.letterhead,
        signup_domain_enabled=cs.signup_domain_enabled, allowed_domain=cs.allowed_domain,
        signup_invite_enabled=cs.signup_invite_enabled, email_configured=mailer.email_configured(cs),
    )


@router.get("/company", response=CompanyOut)
def company(request):
    require_manager(request)
    return _company_out(CompanySettings.load())


@router.patch("/company", response=CompanyOut)
def update_company(request, data: CompanyIn):
    manager = require_manager(request)
    cs = CompanySettings.load()
    changes = data.dict(exclude_none=True)
    if "allowed_domain" in changes:
        changes["allowed_domain"] = changes["allowed_domain"].strip().lower().lstrip("@")
    if "letterhead" in changes:
        changes["letterhead"] = clean_letterhead(changes["letterhead"])
    for field, value in changes.items():
        setattr(cs, field, value)
    cs.save(update_fields=list(changes))
    audit_data = {k: ("(updated)" if k == "letterhead" else v) for k, v in changes.items()}
    audit(manager, "company_settings_changed", "", **audit_data)
    return _company_out(cs)


@router.post("/invites", response=InviteOut)
def create_invite(request, data: InviteIn):
    manager = require_manager(request)
    if data.max_uses is not None and data.max_uses < 1:
        raise HttpError(422, "max_uses must be at least 1, or empty for unlimited")
    invite = InviteCode.objects.create(created_by=manager, max_uses=data.max_uses, expires_at=data.expires_at)
    audit(manager, "invite_created", str(invite.id), max_uses=invite.max_uses)
    return invite


@router.get("/invites", response=list[InviteOut])
def invites(request):
    require_manager(request)
    return InviteCode.objects.order_by("-created_at")


@router.post("/invites/{invite_id}/deactivate", response=InviteOut)
def deactivate_invite(request, invite_id: int):
    manager = require_manager(request)
    invite = get_object_or_404(InviteCode, pk=invite_id)
    invite.active = False
    invite.save(update_fields=["active"])
    audit(manager, "invite_deactivated", str(invite.id))
    return invite
