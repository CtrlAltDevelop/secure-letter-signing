"""Referral endpoints: refer / list under a letter, respond under /referrals."""
from uuid import UUID

from ninja import Router
from ninja.errors import HttpError

from accounts.auth import BearerAuth, user_of

from . import access, referrals, rules
from .schemas import ReferIn, ReferralOut, ReferralRespondIn

router = Router(tags=["letters"], auth=BearerAuth())
referrals_router = Router(tags=["letters"], auth=BearerAuth())


@router.post("/{uuid:letter_id}/refer", response={201: list[ReferralOut]})
def refer(request, letter_id: UUID, data: ReferIn):
    user = user_of(request)
    access.get_visible(user, letter_id)
    rows = referrals.refer(user, letter_id, data.user_ids, data.note)
    return 201, [referrals.referral_out(r) for r in rows]


@router.get("/{uuid:letter_id}/referrals", response=list[ReferralOut])
def list_referrals(request, letter_id: UUID):
    user = user_of(request)
    letter = access.get_visible(user, letter_id)
    if not (rules.is_participant(user, letter) or rules.is_referee(user, letter)):
        raise HttpError(403, "Only participants and referees can see referrals")
    return referrals.list_referrals(letter)


@referrals_router.post("/{int:referral_id}/respond", response=ReferralOut)
def respond(request, referral_id: int, data: ReferralRespondIn):
    row = referrals.respond(user_of(request), referral_id, data.status, data.note)
    return referrals.referral_out(row)
