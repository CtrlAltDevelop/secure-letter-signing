"""Unified search for letters the caller may see: title, number, participants, labels (bodies are not scanned)."""
from accounts.models import User
from workspace.search import hit

from .inbox import metadata_search


def search(user: User, q: str, limit: int) -> list[dict]:
    return [hit("letters", "letter", x.id, x.subject_id, x.title, str(x.no), x.created_at)
            for x in metadata_search(user, q, limit)]
