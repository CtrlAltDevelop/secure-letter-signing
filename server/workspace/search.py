"""Unified search: merges the per-module `ModuleSpec.search` callbacks plus workspace file names.

Each module only returns what its own visibility rules let the caller see, and only identifying fields. The merge is
fair (every module gets an equal share first, leftovers go to modules in registry order) and stable.
"""
import logging

from accounts.models import User

from . import registry
from .models import File

logger = logging.getLogger(__name__)
MIN_QUERY = 2
MAX_LIMIT = 50
FILES = "files"
FILE_CANDIDATES = 200


def _file_hits(user: User, text: str, limit: int) -> list[dict]:
    """File names the caller can see through each subject's own `can`."""
    enabled = registry.enabled_modules()
    rows = (File.objects.filter(active=True, name__icontains=text).select_related("subject")
            .order_by("-created_at", "-id")[:FILE_CANDIDATES])
    seen: dict = {}
    out = []
    for f in rows:
        module = f.subject.module
        if module not in enabled:
            continue
        spec = registry.get(module)
        if spec is None:
            continue
        if f.subject_id not in seen:
            obj = spec.resolve(f.subject)
            seen[f.subject_id] = (obj, spec.title(obj) if obj is not None and spec.title else "") \
                if obj is not None and spec.can(user, obj, "see") else None
        if seen[f.subject_id] is None:
            continue
        out.append({"module": FILES, "kind": "file", "id": str(f.id), "subject_id": str(f.subject_id),
                    "title": f.name, "snippet": seen[f.subject_id][1], "at": f.created_at})
        if len(out) >= limit:
            break
    return out


def _module_hits(user: User, text: str, wanted: set[str], limit: int) -> dict[str, list[dict]]:
    enabled = registry.enabled_modules()
    results: dict[str, list[dict]] = {}
    for spec in registry.all_specs():
        if spec.search is None or spec.code not in enabled or (wanted and spec.code not in wanted):
            continue
        try:
            results[spec.code] = spec.search(user, text, limit)[:limit]
        except Exception:  # noqa: BLE001  one broken module must not take the whole search down
            logger.exception("Search failed in module %s", spec.code)
    if not wanted or FILES in wanted:
        results[FILES] = _file_hits(user, text, limit)
    return results


def merge(results: dict[str, list[dict]], limit: int) -> list[dict]:
    """Equal quota per module first, then leftover slots filled in module order."""
    live = [code for code, rows in results.items() if rows]
    if not live:
        return []
    quota = max(1, limit // len(live))
    taken = {code: results[code][:quota] for code in live}
    room = limit - sum(len(rows) for rows in taken.values())
    for code in live:
        extra = results[code][len(taken[code]): len(taken[code]) + max(room, 0)]
        taken[code] += extra
        room -= len(extra)
    return [hit for code in live for hit in taken[code]][:limit]


def run(user: User, text: str, wanted: set[str], limit: int) -> list[dict]:
    return merge(_module_hits(user, text, wanted, limit), limit)


_DIGITS = str.maketrans("۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩٬,، ", "01234567890123456789    ")


def amount_of(text: str) -> int | None:
    """`text` as a whole number (Persian or Arabic digits and thousand separators allowed), else None."""
    cleaned = text.translate(_DIGITS).replace(" ", "")
    return int(cleaned) if cleaned.isdigit() and len(cleaned) <= 15 else None


def hit(module: str, kind: str, obj_id, subject_id, title: str, snippet: str = "", at=None) -> dict:
    return {"module": module, "kind": kind, "id": str(obj_id), "subject_id": str(subject_id) if subject_id else None,
            "title": title, "snippet": snippet, "at": at}
