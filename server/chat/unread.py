"""Unread and mention counters, computed from `last_read_seq` (one aggregate query plus one for mentions)."""
from collections.abc import Iterable
from dataclasses import dataclass

from django.db.models import Count, OuterRef, Q, Subquery
from django.db.models.functions import Coalesce

from accounts.models import User

from .models import ConversationMember, Message

MENTION_SCAN = 2000  # unread messages carrying mentions examined per call


@dataclass(frozen=True)
class Counts:
    unread: int
    mentions: int
    muted: bool
    last_read_seq: int


def counts_for(user: User, conversation_ids: Iterable | None = None) -> dict:
    """conversation id -> Counts for the user's active memberships (optionally limited to some conversations)."""
    unread_sq = (Message.objects.filter(conversation=OuterRef("conversation_id"), seq__gt=OuterRef("last_read_seq"),
                                        deleted=False).exclude(author=user).order_by().values("conversation")
                 .annotate(c=Count("pk")).values("c"))
    rows = ConversationMember.objects.filter(user=user, active=True).annotate(unread=Coalesce(Subquery(unread_sq), 0))
    if conversation_ids is not None:
        rows = rows.filter(conversation_id__in=list(conversation_ids))
    rows = list(rows)
    mention_rows = (Message.objects.filter(conversation_id__in=[r.conversation_id for r in rows], deleted=False)
                    .exclude(author=user).filter(~Q(mentions=[])).order_by("-id")
                    .values_list("conversation_id", "seq", "mentions")[:MENTION_SCAN])
    reads = {r.conversation_id: r.last_read_seq for r in rows}
    mentioned: dict = {}
    for conv_id, seq, ids in mention_rows:
        if seq > reads[conv_id] and user.id in ids:
            mentioned[conv_id] = mentioned.get(conv_id, 0) + 1
    return {r.conversation_id: Counts(r.unread, mentioned.get(r.conversation_id, 0), r.muted, r.last_read_seq)
            for r in rows}
