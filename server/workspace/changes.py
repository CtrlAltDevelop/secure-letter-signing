"""ChangeHistory rows for module objects. Fields named in `secret` record `{"changed": true}` instead of values."""
from collections.abc import Collection
from datetime import date, datetime
from typing import Any

from accounts.models import User

from .models import ChangeHistory, Subject


def _json(value: Any) -> Any:
    return value.isoformat() if isinstance(value, (datetime, date)) else value


def log(subject: Subject, actor: User | None, field: str, old: Any = None, new: Any = None,
        secret: Collection[str] = ()) -> None:
    if field in secret:
        old, new = None, {"changed": True}
    ChangeHistory.objects.create(subject=subject, actor=actor, field=field, old=_json(old), new=_json(new))


def log_all(subject: Subject, actor: User | None, changes: dict[str, tuple[Any, Any]],
            secret: Collection[str] = ()) -> None:
    for field, (old, new) in changes.items():
        log(subject, actor, field, old, new, secret)
