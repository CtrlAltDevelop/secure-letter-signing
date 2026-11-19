"""`/me/prefs`, `/me/personal-email`, `/me/background` (mounted next to the other `/me` routes)."""
from datetime import date, datetime

from django.core.exceptions import ValidationError
from django.core.validators import validate_email
from django.http import HttpResponse
from ninja import File, Router, Schema
from ninja.errors import HttpError
from ninja.files import UploadedFile
from pydantic import Field

from . import prefs, ratelimit
from .api_auth import Detail
from .auth import BearerAuth, user_of
from .models import UserPrefs

router = Router(tags=["me"], auth=BearerAuth())
EMAIL_REQUESTS_PER_WINDOW = 5


class PrefsOut(Schema):
    theme: str
    birthday: date | None
    birthday_visible: bool
    dnd_until: datetime | None
    personal_email: str
    personal_email_verified: bool
    has_background: bool


class PrefsPatch(Schema):
    theme: str | None = Field(None, pattern="^(light|dark|auto)$")
    birthday: date | None = None  # null clears it
    birthday_visible: bool | None = None
    dnd_until: datetime | None = None  # null clears it


class PersonalEmailIn(Schema):
    email: str = Field(max_length=254)


class TokenIn(Schema):
    token: str = Field(max_length=500)


def _out(row: UserPrefs) -> PrefsOut:
    return PrefsOut(theme=row.theme, birthday=row.birthday, birthday_visible=row.birthday_visible,
                    dnd_until=row.dnd_until, personal_email=row.personal_email,
                    personal_email_verified=row.personal_email_verified, has_background=row.background_active)


@router.get("/prefs", response=PrefsOut)
def get_prefs(request):
    return _out(prefs.prefs_of(user_of(request)))


@router.patch("/prefs", response={200: PrefsOut, 422: Detail})
def patch_prefs(request, data: PrefsPatch):
    row = prefs.prefs_of(user_of(request))
    changed = data.model_fields_set
    if "birthday" in changed and data.birthday and data.birthday > date.today():
        raise HttpError(422, "The birthday cannot be in the future")
    for field in ("theme", "birthday", "birthday_visible", "dnd_until"):
        if field in changed and (getattr(data, field) is not None or field in ("birthday", "dnd_until")):
            setattr(row, field, getattr(data, field))
    row.save()
    return _out(row)


@router.post("/personal-email", response={200: Detail, 422: Detail, 429: Detail, 503: Detail})
def personal_email(request, data: PersonalEmailIn):
    user = user_of(request)
    email = data.email.strip().lower()
    try:
        validate_email(email)
    except ValidationError as exc:
        raise HttpError(422, "Invalid email address") from exc
    ratelimit.hit("personal-email", str(user.id), EMAIL_REQUESTS_PER_WINDOW)
    prefs.start_email_verification(user, email)
    return {"detail": "A verification token was sent"}


@router.post("/personal-email/verify", response={200: PrefsOut, 400: Detail, 429: Detail})
def personal_email_verify(request, data: TokenIn):
    user = user_of(request)
    ratelimit.hit("personal-email-verify", str(user.id), 10)
    return _out(prefs.verify_email(user, data.token))


@router.post("/background", response={200: PrefsOut, 413: Detail, 422: Detail})
def upload_background(request, file: UploadedFile = File(...)):
    user = user_of(request)
    if file.size > prefs.BACKGROUND_MAX_BYTES:
        raise HttpError(413, "The image is larger than 2 MB")
    return _out(prefs.set_background(user, file.read()))


@router.get("/background")
def get_background(request):
    data, content_type = prefs.read_background(user_of(request))
    return HttpResponse(data, content_type=content_type)


@router.delete("/background", response={204: None, 404: Detail})
def delete_background(request):
    prefs.clear_background(user_of(request))
    return 204, None
