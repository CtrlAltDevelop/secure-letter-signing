"""Files attached to any subject: encrypted at rest through `core.filestore`, never deleted (deactivated)."""
import hashlib
import re
from pathlib import PurePosixPath, PureWindowsPath

from django.conf import settings
from django.db import transaction
from django.http import HttpResponse
from django.utils.http import content_disposition_header
from ninja.errors import HttpError
from ninja.files import UploadedFile

from accounts.models import User
from core import filestore

from .access import Access
from .comments import audience_without
from .events import emit
from .models import File, Subject
from .schemas import FileOut, user_ref

MAX_FILES_PER_SUBJECT = 20
MAX_NAME = 200
_CONTROL = re.compile(r"[\x00-\x1f\x7f]")


def safe_name(raw: str) -> str:
    """Last path component without control characters, at most 200 chars; never empty."""
    base = PurePosixPath(PureWindowsPath(raw).as_posix()).name
    return _CONTROL.sub("", base).strip()[:MAX_NAME] or "file"


def file_out(f: File) -> FileOut:
    return FileOut(id=f.id, name=f.name, content_type=f.content_type, size=f.size, sha256=f.sha256_plain,
                   uploaded_by=user_ref(f.uploaded_by), created_at=f.created_at)


def active_files(subject: Subject):
    return File.objects.filter(subject=subject, active=True).select_related("uploaded_by").order_by("created_at", "id")


@transaction.atomic
def upload(user: User, acc: Access, upload_file: UploadedFile, content_type: str, name: str) -> File:
    Subject.objects.select_for_update().get(pk=acc.subject.pk)  # serialises the per-subject file count
    active = File.objects.filter(subject=acc.subject, active=True).count()
    if acc.spec.file_check:
        acc.spec.file_check(acc.obj, content_type, active)
    cap = acc.spec.max_files or MAX_FILES_PER_SUBJECT
    if active >= cap:
        raise HttpError(422, f"At most {cap} files per item")
    if content_type not in filestore.ATTACHMENT_TYPES | acc.spec.file_types:
        raise HttpError(422, "Only PDF and images are allowed")
    if upload_file.size > settings.MAX_ATTACHMENT_BYTES:
        raise HttpError(413, "File is larger than 25 MB")
    if upload_file.size == 0:
        raise HttpError(422, "File is empty")
    data = upload_file.read()
    row = File(subject=acc.subject, uploaded_by=user, name=safe_name(name or upload_file.name or ""),
               content_type=content_type, size=len(data), sha256_plain=hashlib.sha256(data).hexdigest())
    filestore.save_encrypted(row.blob, data)
    row.save()
    emit(acc.subject.module, "file.added", acc.subject, acc.title, user, audience_without(acc, user),
         file_id=str(row.id), size=row.size)
    return row


def download_response(row: File) -> HttpResponse:
    try:
        plain = filestore.read_decrypted(row.blob)
    except filestore.DecryptError as exc:
        raise HttpError(500, "File cannot be decrypted; check DJANGO_DATA_KEY") from exc
    if hashlib.sha256(plain).hexdigest() != row.sha256_plain:
        raise HttpError(500, "File is corrupted")
    response = HttpResponse(plain, content_type=row.content_type)
    response["Content-Disposition"] = content_disposition_header(as_attachment=True, filename=row.name)
    response["X-Content-Type-Options"] = "nosniff"
    return response
