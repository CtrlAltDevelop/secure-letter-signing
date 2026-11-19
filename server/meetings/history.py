"""ChangeHistory rows for meetings. Encrypted values (description, resolution text) record `{"changed": true}` only."""
from datetime import date, datetime
from typing import Any

from accounts.models import User
from workspace.models import ChangeHistory, Subject


def _is_encrypted(field: str) -> bool:
    return field == "description" or field.endswith(":text")


def _json(value: Any) -> Any:
    return value.isoformat() if isinstance(value, (datetime, date)) else value


def log(subject: Subject, actor: User | None, field: str, old: Any = None, new: Any = None) -> None:
    if _is_encrypted(field):
        old, new = None, {"changed": True}
    ChangeHistory.objects.create(subject=subject, actor=actor, field=field, old=_json(old), new=_json(new))


def log_all(subject: Subject, actor: User | None, changes: dict[str, tuple[Any, Any]]) -> None:
    for field, (old, new) in changes.items():
        log(subject, actor, field, old, new)
