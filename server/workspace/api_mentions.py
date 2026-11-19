"""`GET /me/mentions`: the comments (and task reports) that mention me, newest first."""
from collections.abc import Iterator
from datetime import datetime
from uuid import UUID

from ninja import Router, Schema
from ninja.errors import HttpError

from accounts.auth import BearerAuth, user_of
from accounts.models import User

from .access import Access, access_for
from .models import Comment, Mention, Subject
from .schemas import UserRef, user_ref
from .textbox import open_text

router = Router(tags=["workspace"], auth=BearerAuth())
MAX_PAGE = 200
MAX_SCAN = 2000  # rows examined per request: mentions of subjects I can no longer see are skipped
EXCERPT_CHARS = 140


class MentionOut(Schema):
    comment_id: int
    subject_id: UUID
    object_id: str  # the module's own object id (task id, letter id ...)
    module: str
    kind: str  # the subject's kind (task, project, letter ...)
    title: str
    excerpt: str
    author: UserRef
    report: bool
    created_at: datetime


def excerpt_of(text: str) -> str:
    flat = " ".join(text.split())
    return flat if len(flat) <= EXCERPT_CHARS else flat[: EXCERPT_CHARS - 1] + "…"


def _visible(user: User, subject: Subject, cache: dict[object, Access | None]) -> Access | None:
    if subject.pk not in cache:
        try:
            cache[subject.pk] = access_for(user, subject, "see")
        except HttpError:
            cache[subject.pk] = None
    return cache[subject.pk]


def _mentions_of(user: User) -> Iterator[Mention]:
    rows = (Mention.objects.filter(user=user, comment__active=True)
            .select_related("comment__subject", "comment__author", "comment__author__org_title")
            .order_by("-comment__created_at", "-comment_id"))
    return iter(rows[:MAX_SCAN])


def _out(comment: Comment, acc: Access) -> MentionOut:
    return MentionOut(
        comment_id=comment.id, subject_id=comment.subject_id, object_id=str(acc.obj.pk), module=comment.subject.module,
        kind=comment.subject.kind, title=acc.title, excerpt=excerpt_of(open_text(comment.body)),
        author=user_ref(comment.author), report=comment.kind == Comment.REPORT, created_at=comment.created_at)


@router.get("/me/mentions", response=list[MentionOut])
def my_mentions(request, limit: int = 50, offset: int = 0):
    user = user_of(request)
    skip, take = max(offset, 0), max(min(limit, MAX_PAGE), 0)
    cache: dict[object, Access | None] = {}
    out: list[MentionOut] = []
    for mention in _mentions_of(user):
        acc = _visible(user, mention.comment.subject, cache)
        if acc is None:
            continue
        if skip:
            skip -= 1
            continue
        if len(out) >= take:
            break
        out.append(_out(mention.comment, acc))
    return out
