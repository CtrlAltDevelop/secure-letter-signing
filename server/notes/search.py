"""Unified search over the caller's own notes (titles; bodies are encrypted and never scanned)."""
from accounts.models import User
from workspace.search import hit

from .models import Note


def search(user: User, q: str, limit: int) -> list[dict]:
    rows = Note.objects.filter(owner=user, title__icontains=q).order_by("-updated_at", "id")[:limit]
    return [hit("notes", "note", n.id, n.subject_id, n.title, "", n.updated_at) for n in rows]
