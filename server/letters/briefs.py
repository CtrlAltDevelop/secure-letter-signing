"""Letter -> LetterBrief with the per-caller extras (labels, archive flag) and the shared counts in few queries."""
from collections import defaultdict
from collections.abc import Sequence

from django.db.models import Count, Q

from accounts.models import User
from workspace.models import Label, SubjectLabel

from .models import ArchiveMark, Letter, Referral, SecretariatEntry
from .schemas import LetterBrief


def _labels(user: User, letters: Sequence[Letter]) -> dict:
    rows = (SubjectLabel.objects.filter(subject_id__in=[x.subject_id for x in letters if x.subject_id],
                                        active=True, label__active=True)
            .filter(Q(label__scope=Label.ORG) | Q(label__owner=user)).values_list("subject_id", "label_id"))
    out: dict = defaultdict(list)
    for subject_id, label_id in rows:
        out[subject_id].append(label_id)
    return out


def _numbers(letters: Sequence[Letter]) -> dict:
    rows = SecretariatEntry.objects.filter(letter__in=letters, active=True).values_list("letter_id", "number")
    return dict(rows)


def _referral_counts(letters: Sequence[Letter]) -> dict:
    rows = Referral.objects.filter(letter__in=letters).values("letter_id").annotate(n=Count("id"))
    return {r["letter_id"]: r["n"] for r in rows}


def briefs(user: User, letters: Sequence[Letter]) -> list[LetterBrief]:
    letters = list(letters)
    labels, numbers, counts = _labels(user, letters), _numbers(letters), _referral_counts(letters)
    archived = set(ArchiveMark.objects.filter(user=user, active=True, letter__in=letters).values_list("letter_id", flat=True))
    return [LetterBrief(
        id=x.id, no=x.no, title=x.title, status=x.status, creator_id=x.creator_id, parent_id=x.parent_id,
        visibility=x.visibility, unlisted=x.unlisted, created_at=x.created_at, sent_at=x.sent_at,
        subject_id=x.subject_id, label_ids=sorted(labels.get(x.subject_id, [])), number_label=numbers.get(x.id, ""),
        referral_count=counts.get(x.id, 0), archived=x.id in archived) for x in letters]


def brief_of(user: User, letter: Letter) -> LetterBrief:
    return briefs(user, [letter])[0]
