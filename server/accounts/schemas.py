from datetime import datetime
from uuid import UUID

from ninja import Schema

from .models import User


class UserOut(Schema):
    id: int
    email: str
    full_name: str
    title: str
    department: str
    is_manager: bool
    is_superuser: bool
    is_active: bool
    permissions: list[str]

    @staticmethod
    def of(user: User) -> "UserOut":
        return UserOut(
            id=user.id, email=user.email, full_name=user.full_name, title=user.title,
            department=user.department, is_manager=user.is_manager, is_superuser=user.is_superuser,
            is_active=user.is_active, permissions=sorted(g.code for g in user.grants.all()),
        )


class TokenOut(Schema):
    access: str
    refresh: str
    session_id: UUID
    user: UserOut


class SessionOut(Schema):
    id: UUID
    device_name: str
    platform: str
    ip: str | None
    created_at: datetime
    last_active: datetime
    current: bool
