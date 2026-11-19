"""Registration of the chat module: only active members see a conversation; `comment` = may post."""
from typing import Any

from workspace.models import Subject
from workspace.registry import ModuleSpec

from . import mirror, rules, transfer, unified
from .models import Conversation

AUDIO_TYPES = frozenset({"audio/mpeg", "audio/mp4", "audio/aac", "audio/ogg", "audio/webm", "audio/wav",
                         "audio/x-m4a", "audio/m4a", "audio/opus"})
MAX_FILES = 100_000  # chats collect many files; the per-subject cap of other modules would stop a busy group


def resolve(subject: Subject) -> Conversation | None:
    conv = Conversation.objects.select_related("subject").filter(subject=subject).first()
    if conv is not None and mirror.is_mirrored(conv):
        mirror.sync(conv, announce=False)
    return conv


def can(user, conv: Any, action: str) -> bool:
    return rules.can(user, conv, action)


def audience(conv: Any) -> set[int]:
    return rules.member_ids(conv)


def title(conv: Any) -> str:
    return conv.name


def spec() -> ModuleSpec:
    from .api import router

    return ModuleSpec("chat", router, resolve, can, audience=audience, title=title, transfer=transfer.transfer,
                      file_types=AUDIO_TYPES, max_files=MAX_FILES, search=unified.search,
                      bookmark_check=unified.bookmark_check)
