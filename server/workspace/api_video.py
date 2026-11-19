"""`/video/*`: join tokens for online meetings (LiveKit). Off until LIVEKIT_* is configured."""
from uuid import UUID

from django.conf import settings
from ninja import Router, Schema
from ninja.errors import HttpError

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, user_of
from accounts.models import audit

from . import video
from .access import access_to

router = Router(tags=["video"], auth=BearerAuth())


class VideoConfigOut(Schema):
    enabled: bool


class VideoJoinIn(Schema):
    subject_id: UUID


class VideoJoinOut(Schema):
    url: str
    token: str
    room: str
    identity: str


@router.get("/video/config", response=VideoConfigOut)
def video_config(request):
    return VideoConfigOut(enabled=video.configured())


@router.post("/video/join", response={200: VideoJoinOut, 403: Detail, 404: Detail, 503: Detail})
def video_join(request, data: VideoJoinIn):
    """Whoever may see the subject may join its room. 503 when no LiveKit server is configured."""
    user = user_of(request)
    if not video.configured():
        raise HttpError(503, "Online meetings are not configured")
    access = access_to(user, data.subject_id, "see")
    room, identity = video.room_name(access.subject.id), video.new_identity(user)
    audit(user, "video_join", str(access.subject.id))
    return VideoJoinOut(url=settings.LIVEKIT_URL, token=video.make_token(user, room, identity), room=room,
                        identity=identity)
