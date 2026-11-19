"""Who may see/do what with a letter. One place, used by every endpoint and the WebSocket replay."""
from django.db.models import Exists, OuterRef, Q, QuerySet

from accounts.models import User

from .models import Letter, Participant, Referral

SEE, CREATE, SIGN = "letter.see", "letter.create", "letter.sign"
SECRETARIAT = "letter.secretariat"


def grants_of(user: User) -> set[str]:
    return set(user.grants.values_list("code", flat=True))


def visible_letters(user: User) -> QuerySet[Letter]:
    """Involved people (creator, signers) always see their letters, including drafts and unlisted ones (history).
    Viewers and the public need `letter.see`, the letter shown to viewers, and it not unlisted."""
    # Drafts are the creator's alone; signers see a letter only once it has been sent.
    involved = Q(creator=user) | (
        Q(participants__user=user, participants__role=Participant.SIGNER) & ~Q(status=Letter.DRAFT)
    )
    # A referee may read the letter (even a private one, even without `letter.see`) unless the manager unlisted it.
    referred = Q(Exists(Referral.objects.filter(letter=OuterRef("pk"), to_user=user))) & ~Q(status=Letter.DRAFT) & Q(
        unlisted=False)
    q = involved | referred
    if SEE in grants_of(user):
        listed = Q(shown_at__isnull=False, unlisted=False)
        q |= listed & (Q(visibility="public") | Q(participants__user=user, participants__role=Participant.VIEWER))
    return Letter.objects.filter(q).distinct()


def can_see(user: User, letter: Letter) -> bool:
    return visible_letters(user).filter(pk=letter.pk).exists()


def audience_ids(letter: Letter) -> set[int]:
    """Users who should receive live events for this letter right now."""
    ids = {letter.creator_id}
    ids |= set(letter.participants.filter(role=Participant.SIGNER).values_list("user_id", flat=True))
    if not letter.unlisted:
        ids |= set(letter.referrals.values_list("to_user_id", flat=True))
    if letter.shown_at and not letter.unlisted:
        if letter.visibility == "public":
            ids |= set(User.objects.filter(is_active=True, grants__code=SEE).values_list("id", flat=True))
        else:
            ids |= set(letter.participants.filter(role=Participant.VIEWER).values_list("user_id", flat=True))
    return ids


def is_participant(user: User, letter: Letter) -> bool:
    """Creator, signer or viewer of the letter (a draft's signers and viewers do not see it yet, so not them)."""
    if letter.creator_id == user.id:
        return True
    return letter.status != Letter.DRAFT and letter.participants.filter(
        user=user, role__in=(Participant.SIGNER, Participant.VIEWER)).exists()


def is_referee(user: User, letter: Letter) -> bool:
    return letter.referrals.filter(to_user=user).exists()


def has_secretariat(user: User) -> bool:
    return SECRETARIAT in grants_of(user)


def next_signer_ids(letter: Letter) -> list[int]:
    """Signers who may sign now: everyone pending (parallel) or only the first pending one (serial)."""
    pending = list(letter.participants.filter(role=Participant.SIGNER, decision="").order_by("position", "id"))
    if letter.order == "serial":
        pending = pending[:1]
    return [p.user_id for p in pending]
