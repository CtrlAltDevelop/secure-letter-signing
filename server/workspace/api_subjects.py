"""Generic endpoints on any subject: comments, files, history, seen-by. Access always goes through the module."""
from uuid import UUID

from django.http import HttpResponse
from django.shortcuts import get_object_or_404
from ninja import File as UploadField
from ninja import Form, Router
from ninja.errors import HttpError
from ninja.files import UploadedFile

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, user_of
from accounts.models import User

from . import comments as comment_svc
from . import files as file_svc
from .access import Access, access_for, access_to
from .models import ChangeHistory, Comment, File, SeenBy
from .seen import mark_seen
from .schemas import (CommentIn, CommentOut, CommentPatch, FileOut, HistoryOut, SeenOut, user_ref)

router = Router(tags=["workspace"], auth=BearerAuth())
MAX_PAGE = 500


# --- comments --------------------------------------------------------------------------------------------------


@router.get("/subjects/{uuid:subject_id}/comments", response={200: list[CommentOut], 404: Detail})
def list_comments(request, subject_id: UUID, limit: int = 200, offset: int = 0):
    acc = access_to(user_of(request), subject_id, "see")
    return comment_svc.list_threads(acc.subject, limit, offset)


@router.post("/subjects/{uuid:subject_id}/comments", response={201: CommentOut, 403: Detail, 422: Detail})
def add_comment(request, subject_id: UUID, data: CommentIn):
    user = user_of(request)
    acc = access_to(user, subject_id, "comment")
    return 201, comment_svc.comment_out(comment_svc.post_comment(user, acc, data))


def _live_comment(comment_id: int) -> Comment:
    return get_object_or_404(Comment.objects.select_related("author", "subject"), pk=comment_id, active=True)


@router.patch("/comments/{int:comment_id}", response={200: CommentOut, 403: Detail, 422: Detail})
def edit_comment(request, comment_id: int, data: CommentPatch):
    user = user_of(request)
    comment = _live_comment(comment_id)
    access_for(user, comment.subject, "comment")
    if comment.author_id != user.id:
        raise HttpError(403, "Only the author can edit a comment")
    return comment_svc.comment_out(comment_svc.edit_comment(comment, data.body.text))


@router.delete("/comments/{int:comment_id}", response={204: None, 403: Detail})
def deactivate_comment(request, comment_id: int):
    user = user_of(request)
    comment = _live_comment(comment_id)
    _author_or_moderator(user, access_for(user, comment.subject, "see"), comment.author_id)
    Comment.objects.filter(pk=comment.pk).update(active=False)
    return 204, None


def _author_or_moderator(user: User, acc: Access, owner_id: int) -> None:
    if owner_id != user.id and not acc.spec.can(user, acc.obj, "moderate"):
        raise HttpError(403, "Permission denied")


# --- files -----------------------------------------------------------------------------------------------------


@router.get("/subjects/{uuid:subject_id}/files", response=list[FileOut])
def list_files(request, subject_id: UUID):
    acc = access_to(user_of(request), subject_id, "see")
    return [file_svc.file_out(f) for f in file_svc.active_files(acc.subject)]


@router.post("/subjects/{uuid:subject_id}/files", response={201: FileOut, 403: Detail, 413: Detail, 422: Detail})
def add_file(request, subject_id: UUID, content_type: Form[str], name: Form[str] = "",
             file: UploadedFile = UploadField(...)):
    user = user_of(request)
    acc = access_to(user, subject_id, "comment")
    row = file_svc.upload(user, acc, file, content_type, name)
    return 201, file_svc.file_out(File.objects.select_related("uploaded_by").get(pk=row.pk))


def _live_file(file_id: UUID) -> File:
    return get_object_or_404(File.objects.select_related("subject", "uploaded_by"), pk=file_id, active=True)


@router.get("/files/{uuid:file_id}", response=None)
def download_file(request, file_id: UUID) -> HttpResponse:
    row = _live_file(file_id)
    access_for(user_of(request), row.subject, "see")
    return file_svc.download_response(row)


@router.delete("/files/{uuid:file_id}", response={204: None, 403: Detail})
def deactivate_file(request, file_id: UUID):
    user = user_of(request)
    row = _live_file(file_id)
    _author_or_moderator(user, access_for(user, row.subject, "see"), row.uploaded_by_id)
    File.objects.filter(pk=row.pk).update(active=False)
    return 204, None


# --- history and seen-by ---------------------------------------------------------------------------------------


@router.get("/subjects/{uuid:subject_id}/history", response=list[HistoryOut])
def history(request, subject_id: UUID, limit: int = 100, offset: int = 0):
    acc = access_to(user_of(request), subject_id, "see")
    start = max(offset, 0)
    rows = (ChangeHistory.objects.filter(subject=acc.subject).select_related("actor")
            .order_by("-at", "-id")[start : start + max(min(limit, MAX_PAGE), 0)])
    return [HistoryOut(id=h.id, actor=user_ref(h.actor) if h.actor else None, field=h.field, old=h.old,
                       new=h.new, at=h.at) for h in rows]


@router.get("/subjects/{uuid:subject_id}/seen", response=list[SeenOut])
def seen_list(request, subject_id: UUID):
    acc = access_to(user_of(request), subject_id, "see")
    rows = SeenBy.objects.filter(subject=acc.subject, user__is_active=True).select_related("user").order_by("first_at", "id")
    return [SeenOut(user=user_ref(s.user), first_at=s.first_at, last_at=s.last_at) for s in rows]


@router.post("/subjects/{uuid:subject_id}/seen", response={204: None})
def seen_mark(request, subject_id: UUID):
    user = user_of(request)
    mark_seen(user, access_to(user, subject_id, "see").subject)
    return 204, None
