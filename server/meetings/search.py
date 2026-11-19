"""Unified search for meetings the caller created or attends (titles only)."""
from accounts.models import User
from workspace.search import hit

from .rules import visible_meetings


def search(user: User, q: str, limit: int) -> list[dict]:
    rows = visible_meetings(user).filter(title__icontains=q).order_by("-updated_at", "id")[:limit]
    return [hit("meetings", "meeting", m.id, m.subject_id, m.title, m.status, m.starts_at or m.updated_at)
            for m in rows]
