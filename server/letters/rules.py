"""Who may see/do what with a letter. One place, used by every endpoint and the WebSocket replay."""
from django.db.models import Q, QuerySet

from accounts.models import User
from keys.models import UserKey

from .models import Letter, Participant

SEE, CREATE, SIGN = "letter.see", "letter.create", "letter.sign"


def grants_of(user: User) -> set[str]:
    return set(user.grants.values_list("code", flat=True))


def visible_letters(user: User) -> QuerySet[Letter]:
    """Involved people (creator, signers) always see their letters, including drafts and unlisted ones (history).
    Viewers and the public need `letter.see`, the letter shown to viewers, and it not unlisted."""
    # Drafts are the creator's alone; signers see a letter only once it has been sent.
    involved = Q(creator=user) | (
        Q(participants__user=user, participants__role=Participant.SIGNER) & ~Q(status=Letter.DRAFT)
    )
    q = involved
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
    if letter.shown_at and not letter.unlisted:
        if letter.visibility == "public":
            ids |= set(User.objects.filter(is_active=True, grants__code=SEE).values_list("id", flat=True))
        else:
            ids |= set(letter.participants.filter(role=Participant.VIEWER).values_list("user_id", flat=True))
    return ids


def readers_ids(letter: Letter) -> set[int]:
    """Users whose active keys must hold a wrapped document key (everyone who may decrypt)."""
    ids = {letter.creator_id}
    ids |= set(letter.participants.filter(role=Participant.SIGNER).values_list("user_id", flat=True))
    if letter.visibility == "private":
        ids |= set(letter.participants.filter(role=Participant.VIEWER).values_list("user_id", flat=True))
    return ids


def required_keys(letter: Letter) -> QuerySet[UserKey]:
    return UserKey.objects.filter(user_id__in=readers_ids(letter), status=UserKey.ACTIVE, user__is_active=True)


def next_signer_ids(letter: Letter) -> list[int]:
    """Signers who may sign now: everyone pending (parallel) or only the first pending one (serial)."""
    pending = list(letter.participants.filter(role=Participant.SIGNER, decision="").order_by("position", "id"))
    if letter.order == "serial":
        pending = pending[:1]
    return [p.user_id for p in pending]
