from datetime import datetime
from uuid import UUID

from ninja import Schema

from .models import CompanySettings, User


class UserOut(Schema):
    id: int
    email: str
    full_name: str
    title: str  # company title name; the legacy free-text title only while no company title is set
    title_id: int | None
    status_text: str
    department: str
    department_id: int | None
    is_manager: bool
    is_superuser: bool
    is_active: bool
    permissions: list[str]
    has_signing_pin: bool
    phone: str
    is_guest: bool = False
    guest_expires_at: datetime | None = None
    two_factor_enabled: bool = False
    two_factor_setup_required: bool = False  # the company requires 2FA and this user has not set it up

    @staticmethod
    def of(user: User, require_2fa: bool | None = None) -> "UserOut":
        if require_2fa is None:
            require_2fa = CompanySettings.load().require_2fa
        return UserOut(
            id=user.id, email=user.email, full_name=user.full_name,
            title=user.org_title.name if user.org_title_id else user.title, title_id=user.org_title_id,
            status_text=user.status_text,
            department=user.department.name if user.department else "", department_id=user.department_id,
            is_manager=user.is_manager, is_superuser=user.is_superuser,
            is_active=user.is_active, permissions=sorted(g.code for g in user.grants.all()),
            has_signing_pin=bool(user.signing_pin_hash), phone=user.phone or "",
            is_guest=user.is_guest, guest_expires_at=user.guest_expires_at, two_factor_enabled=user.totp_enabled,
            two_factor_setup_required=bool(require_2fa) and not user.totp_enabled,
        )


class TokenOut(Schema):
    access: str
    refresh: str
    session_id: UUID
    user: UserOut
    two_factor_setup_required: bool = False


class TwoFactorChallengeOut(Schema):
    """Password was right and the account has 2FA: no session yet; finish with POST /auth/login/2fa."""

    two_factor_required: bool = True
    challenge: str


class SessionOut(Schema):
    id: UUID
    device_name: str
    platform: str
    ip: str | None
    created_at: datetime
    last_active: datetime
    current: bool
    biometric: bool
