"""Letter lists: boxes, advanced search, per-user archive."""
from datetime import date
from uuid import UUID

from django.db import transaction
from django.utils import timezone
from ninja import Query, Router

from accounts.auth import BearerAuth, user_of

from . import access, briefs, inbox
from .models import ArchiveMark
from .schemas import ArchiveIn, LetterBrief

router = Router(tags=["letters"], auth=BearerAuth())


@router.get("/search", response=list[LetterBrief])
def search_letters(request, q: str = "", status: str = "", label: int | None = None, number: str = "",
                   from_: date | None = Query(None, alias="from"), to: date | None = None, creator: str = "",
                   signer: str = "", box: str = "all", limit: int = 100, offset: int = 0):
    """Titles, numbers, participants, labels and (most recent 500 visible letters) decrypted body text."""
    inbox.check_box(box)
    user = user_of(request)
    rows = inbox.search(user, q=q, box=box, limit=limit, offset=offset, status=status, label=label, number=number,
                        created_from=from_, created_to=to, creator=creator, signer=signer)
    return briefs.briefs(user, rows)


@router.post("/{uuid:letter_id}/archive", response=LetterBrief)
@transaction.atomic
def archive_letter(request, letter_id: UUID, data: ArchiveIn):
    user = user_of(request)
    letter = access.get_visible(user, letter_id)
    row, created = ArchiveMark.objects.get_or_create(letter=letter, user=user, defaults={"active": data.archived})
    if not created and row.active != data.archived:
        ArchiveMark.objects.filter(pk=row.pk).update(active=data.archived, at=timezone.now())
    return briefs.brief_of(user, letter)
