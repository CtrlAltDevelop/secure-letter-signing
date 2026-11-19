"""Referring a letter to colleagues for a decision. A referee reads the letter (never signs unless a signer)."""
from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja.errors import HttpError

from accounts.models import User, audit
from accounts.notify import notify
from workspace.schemas import TextBody, user_ref
from workspace.textbox import open_text, seal_text

from . import notices, rules
from .models import Letter, Referral
from .schemas import ReferralOut

MAX_REFEREES = 50


def require_can_refer(user: User, letter: Letter) -> None:
    """Participants and referees who can see the letter; a draft cannot be referred and nor can a cancelled letter."""
    if not (rules.is_participant(user, letter) or rules.is_referee(user, letter)):
        raise HttpError(403, "Only participants and referees can refer a letter")
    if letter.status in (Letter.DRAFT, Letter.CANCELLED):
        raise HttpError(409, f"Letter is {letter.status}")


def referral_out(r: Referral) -> ReferralOut:
    return ReferralOut(
        id=r.id, letter_id=r.letter_id, from_user=user_ref(r.from_user), to_user=user_ref(r.to_user),
        note=TextBody(text=open_text(r.note)), status=r.status, response_note=TextBody(text=open_text(r.response_note)),
        created_at=r.created_at, responded_at=r.responded_at)


def list_referrals(letter: Letter) -> list[ReferralOut]:
    rows = letter.referrals.select_related("from_user", "to_user").order_by("created_at", "id")
    return [referral_out(r) for r in rows]


def _referees(user: User, user_ids: list[int], letter: Letter) -> list[User]:
    wanted = list(dict.fromkeys(i for i in user_ids if i != user.id))
    people = list(User.objects.filter(pk__in=wanted, is_active=True))
    if len(people) != len(wanted):
        raise HttpError(422, "Unknown or inactive user")
    pending = set(letter.referrals.filter(status=Referral.PENDING).values_list("to_user_id", flat=True))
    return [p for p in people if p.id not in pending]  # already waiting on a decision: nothing to add


@transaction.atomic
def refer(user: User, letter_id, user_ids: list[int], note: str) -> list[Referral]:
    letter = get_object_or_404(Letter.objects.select_for_update(), pk=letter_id)
    require_can_refer(user, letter)
    people = _referees(user, user_ids, letter)
    sealed = seal_text(note.strip())
    rows = [Referral.objects.create(letter=letter, from_user=user, to_user=p, note=sealed) for p in people]
    if rows:
        ids = [p.id for p in people]
        audit(user, "letter_referred", str(letter.id), to=ids)
        notices.history(letter.subject, user, "referral", None, {"to": ids})
        notify(people, "letter_referral", f"Referred to you: {letter.title}", letter_id=str(letter.id))
        notices.announce(letter, "referred", user, to_ids=ids, referral_ids=[r.id for r in rows])
    return rows


@transaction.atomic
def respond(user: User, referral_id: int, status: str, note: str) -> Referral:
    row = get_object_or_404(Referral.objects.select_for_update().select_related("letter", "from_user", "to_user"),
                            pk=referral_id, to_user=user)
    if row.status != Referral.PENDING:
        raise HttpError(409, f"Referral is already {row.status}")
    row.status, row.responded_at, row.response_note = status, timezone.now(), seal_text(note.strip())
    row.save(update_fields=["status", "responded_at", "response_note"])
    letter = row.letter
    audit(user, "referral_responded", str(letter.id), referral=row.id, status=status)
    notices.history(letter.subject, user, "referral_response", None, {"referral": row.id, "status": status})
    notify([row.from_user], "referral_response", f"Referral {status}: {letter.title}", letter_id=str(letter.id),
           referral_id=row.id)
    notices.announce(letter, "referral_responded", user, referral_id=row.id, status=status)
    return row
