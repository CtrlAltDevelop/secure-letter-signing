"""Boxes (inbox / outbox / archive / all) and advanced search over the letters a user may see."""
import logging
from datetime import date

from django.db.models import Exists, OuterRef, Q, QuerySet
from ninja.errors import HttpError

from accounts.models import User
from core import cryptoutil
from workspace.access import visible_labels
from workspace.models import SubjectLabel

from . import rules
from .models import ArchiveMark, Letter, Participant, Referral, SecretariatEntry

logger = logging.getLogger(__name__)
BOXES = ("inbox", "outbox", "archive", "all")
BODY_SCAN_CAP = 500  # body text is searched only in the most recent letters (it must be decrypted one by one)
MAX_LIMIT = 200


def _archived(user: User) -> Exists:
    return Exists(ArchiveMark.objects.filter(letter=OuterRef("pk"), user=user, active=True))


def box_of(user: User, rows: QuerySet[Letter], box: str) -> QuerySet[Letter]:
    """inbox = I sign it, was shown it as a viewer, or was referred it, and have not archived it;
    outbox = I created it (not archived); archive = archived by me; all = everything visible."""
    if box == "outbox":
        return rows.filter(creator=user).exclude(_archived(user))
    if box == "archive":
        return rows.filter(_archived(user))
    if box == "inbox":
        mine = Participant.objects.filter(letter=OuterRef("pk"), user=user)
        signer = Exists(mine.filter(role=Participant.SIGNER))
        viewer = Exists(mine.filter(role=Participant.VIEWER)) & Q(shown_at__isnull=False)
        referred = Exists(Referral.objects.filter(letter=OuterRef("pk"), to_user=user))
        return rows.filter(Q(signer) | Q(viewer) | Q(referred)).exclude(_archived(user))
    return rows


def check_box(box: str) -> None:
    if box not in BOXES:
        raise HttpError(422, "box must be inbox, outbox, archive or all")


def paged(rows: QuerySet[Letter], limit: int, offset: int) -> list[Letter]:
    start = max(offset, 0)
    return list(rows[start : start + max(min(limit, MAX_LIMIT), 0)])


def _people_filter(text: str, prefix: str) -> Q:
    text = text.strip()
    if text.isdigit():
        return Q(**{f"{prefix}__id": int(text)})
    return Q(**{f"{prefix}__email__icontains": text}) | Q(**{f"{prefix}__full_name__icontains": text})


def _structured(user: User, rows: QuerySet[Letter], *, status: str, label: int | None, number: str,
                created_from: date | None, created_to: date | None, creator: str, signer: str) -> QuerySet[Letter]:
    wanted = {s for s in status.split(",") if s}
    if wanted:
        rows = rows.filter(status__in=wanted)
    if label is not None:
        ok = visible_labels(user).filter(pk=label, active=True).exists()
        subjects = SubjectLabel.objects.filter(label_id=label, active=True).values("subject_id") if ok else []
        rows = rows.filter(subject_id__in=subjects)
    if number.strip():
        needle = number.strip()
        numbered = SecretariatEntry.objects.filter(active=True, number__icontains=needle, letter__isnull=False)
        by_no = Q(no=int(needle)) if needle.isdigit() else Q(pk__in=[])
        rows = rows.filter(Q(pk__in=numbered.values("letter_id")) | by_no)
    if created_from:
        rows = rows.filter(created_at__date__gte=created_from)
    if created_to:
        rows = rows.filter(created_at__date__lte=created_to)
    if creator.strip():
        rows = rows.filter(_people_filter(creator, "creator"))
    if signer.strip():
        match = Participant.objects.filter(role=Participant.SIGNER).filter(_people_filter(signer, "user"))
        rows = rows.filter(pk__in=match.values("letter_id"))
    return rows


def _metadata_hits(user: User, rows: QuerySet[Letter], text: str) -> set:
    """Letters whose title, number, participants or labels match `text`."""
    people = Q(participants__user__email__icontains=text) | Q(participants__user__full_name__icontains=text)
    people |= Q(creator__email__icontains=text) | Q(creator__full_name__icontains=text)
    labels = visible_labels(user).filter(active=True, name__icontains=text).values("pk")
    labelled = SubjectLabel.objects.filter(active=True, label__in=labels).values("subject_id")
    numbers = SecretariatEntry.objects.filter(active=True, letter__isnull=False).filter(
        Q(number__icontains=text) | Q(title__icontains=text) | Q(party_name__icontains=text)).values("letter_id")
    match = Q(title__icontains=text) | people | Q(subject_id__in=labelled) | Q(pk__in=numbers)
    if text.isdigit():
        match |= Q(no=int(text))
    return set(rows.filter(match).values_list("pk", flat=True))


def _body_hits(rows: QuerySet[Letter], text: str, skip: set) -> set:
    """Decrypted body text, only for letters the caller can see (`rows` is already scoped), most recent 500."""
    needle, hits = text.casefold(), set()
    for letter in rows.exclude(pk__in=skip).order_by("-no")[:BODY_SCAN_CAP]:
        try:
            body = cryptoutil.decrypt_body(letter.body)
        except cryptoutil.DecryptError:
            logger.error("Letter %s cannot be decrypted during search", letter.id)
            continue
        if needle in str(body.get("text", "")).casefold():
            hits.add(letter.pk)
    return hits


def search(user: User, *, q: str, box: str, limit: int, offset: int, **filters) -> list[Letter]:
    rows = box_of(user, rules.visible_letters(user), box)
    rows = _structured(user, Letter.objects.filter(pk__in=rows.values("pk")), **filters)
    if q.strip():
        text = q.strip()
        found = _metadata_hits(user, rows, text)
        found |= _body_hits(rows, text, found)
        rows = rows.filter(pk__in=found)
    return paged(rows.order_by("-no"), limit, offset)


def metadata_search(user: User, text: str, limit: int) -> list[Letter]:
    """Visible letters whose title, number, participants or labels match `text` (no body scan), newest first."""
    rows = Letter.objects.filter(pk__in=rules.visible_letters(user).values("pk"))
    return list(rows.filter(pk__in=_metadata_hits(user, rows, text)).order_by("-no")[:limit])
