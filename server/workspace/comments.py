"""Comments on any subject: threads (one reply level), reports, edit-by-replacement, deactivation."""
from django.db import transaction
from django.db.models import Prefetch
from ninja.errors import HttpError

from accounts import guests
from accounts.models import User
from accounts.notify import notify

from .access import Access
from .events import emit
from .models import Comment, Mention, Subject
from .schemas import CommentIn, CommentOut, TextBody, user_ref
from .textbox import open_text, seal_text

MAX_PAGE = 500


def audience_without(acc: Access, actor: User) -> set[int]:
    ids = set(acc.spec.audience(acc.obj)) if acc.spec.audience else set()
    ids.discard(actor.id)
    return ids


def comment_out(c: Comment, replies: list[CommentOut] | None = None) -> CommentOut:
    mentioned = [user_ref(m.user) for m in sorted(c.mentions.all(), key=lambda m: m.user_id)]
    return CommentOut(id=c.id, author=user_ref(c.author), kind=c.kind, body=TextBody(text=open_text(c.body)),
                      progress=c.progress_snapshot, parent_id=c.parent_id, edited=c.replaces_id is not None,
                      created_at=c.created_at, mentions=mentioned, replies=replies or [])


def list_threads(subject: Subject, limit: int, offset: int) -> list[CommentOut]:
    replies = Prefetch("replies", queryset=Comment.objects.filter(active=True).select_related("author")
                       .prefetch_related("mentions__user").order_by("created_at", "id"), to_attr="live_replies")
    start = max(offset, 0)
    roots = (Comment.objects.filter(subject=subject, parent=None, active=True).select_related("author")
             .prefetch_related(replies, "mentions__user").order_by("created_at", "id")[start : start + max(min(limit, MAX_PAGE), 0)])
    return [comment_out(c, [comment_out(r) for r in c.live_replies]) for c in roots]


def _checked_text(text: str) -> str:
    text = text.strip()
    if not text:
        raise HttpError(422, "Text is required")
    return text


def _parent_of(subject: Subject, data: CommentIn) -> Comment | None:
    if data.parent_id is None:
        return None
    parent = Comment.objects.filter(pk=data.parent_id, subject=subject, active=True).first()
    if parent is None:
        raise HttpError(422, "Unknown parent comment")
    if parent.parent_id is not None or data.kind != Comment.COMMENT:
        raise HttpError(422, "Replies go one level deep and must be plain comments")
    return parent


def _report_progress(user: User, acc: Access, data: CommentIn) -> int | None:
    """Reports belong to people who may report progress (task owners). Returns the stored progress, if any."""
    if data.kind != Comment.REPORT:
        if data.progress is not None:
            raise HttpError(422, "Only a report can carry progress")
        return None
    if acc.spec.set_progress is None:
        raise HttpError(422, "Reports are not supported here")
    if not acc.spec.can(user, acc.obj, "progress"):
        raise HttpError(403, "Permission denied")
    return None if data.progress is None else acc.spec.set_progress(acc.obj, user, data.progress)


def _checked_mentions(acc: Access, author: User, ids: list[int]) -> list[User]:
    """The mentioned users (duplicates dropped); 422 unless every one is active and can see the subject."""
    wanted = list(dict.fromkeys(ids))
    users = list(guests.visible_users(author, User.objects.filter(pk__in=wanted, is_active=True)).select_related("org_title"))
    if len(users) != len(wanted):
        raise HttpError(422, "Unknown or inactive user mentioned")
    if not all(acc.spec.can(u, acc.obj, "see") for u in users):
        raise HttpError(422, "A mentioned user cannot see this item")
    return users


def _announce_mentions(acc: Access, comment: Comment, author: User, mentioned: list[User]) -> None:
    others = [u for u in mentioned if u.id != author.id]
    if not others:
        return
    emit(acc.subject.module, "mention", acc.subject, acc.title, author, [u.id for u in others],
         comment_id=comment.id, report=comment.kind == Comment.REPORT)
    notify(others, "mention", acc.title, module=acc.subject.module, subject_id=str(acc.subject.pk),
           comment_id=comment.id)


@transaction.atomic
def post_comment(user: User, acc: Access, data: CommentIn) -> Comment:
    text = _checked_text(data.body.text)
    parent = _parent_of(acc.subject, data)
    mentioned = _checked_mentions(acc, user, data.mentions)
    snapshot = _report_progress(user, acc, data)
    comment = Comment.objects.create(subject=acc.subject, author=user, parent=parent, kind=data.kind,
                                     body=seal_text(text), progress_snapshot=snapshot)
    Mention.objects.bulk_create([Mention(comment=comment, user=u) for u in mentioned])
    emit(acc.subject.module, "comment.created", acc.subject, acc.title, user, audience_without(acc, user),
         comment_id=comment.id, parent_id=comment.parent_id, report=data.kind == Comment.REPORT)
    _announce_mentions(acc, comment, user, mentioned)
    return comment


def add_note(subject: Subject, author: User, text: str, progress: int | None) -> Comment:
    """System-made report comment (for example a rejection note); no event, the caller emits its own."""
    return Comment.objects.create(subject=subject, author=author, kind=Comment.REPORT, body=seal_text(text),
                                  progress_snapshot=progress)


@transaction.atomic
def edit_comment(comment: Comment, text: str) -> Comment:
    """A replacing row with the same place in the thread; the old row is deactivated, never changed or deleted."""
    new = Comment.objects.create(
        subject=comment.subject, author=comment.author, parent=comment.parent, kind=comment.kind,
        body=seal_text(_checked_text(text)), progress_snapshot=comment.progress_snapshot, replaces=comment,
        created_at=comment.created_at)
    old_mentions = Mention.objects.filter(comment=comment).values_list("user_id", flat=True)
    Mention.objects.bulk_create([Mention(comment=new, user_id=uid) for uid in old_mentions])
    Comment.objects.filter(parent=comment, active=True).update(parent=new)
    Comment.objects.filter(pk=comment.pk).update(active=False)
    return new
