"""Online meetings through a self-hosted LiveKit server: this module only mints short-lived join tokens.

A room belongs to a subject (a meeting, a chat conversation ...). Whoever may `see` the subject may join; the
media itself never touches this server. Token = LiveKit access JWT (HS256, API key as issuer)."""
import base64
import hashlib
import hmac
import json
import secrets
import time

from django.conf import settings

from accounts.models import User

TOKEN_TTL_SECONDS = 2 * 60 * 60


def configured() -> bool:
    return bool(settings.LIVEKIT_URL and settings.LIVEKIT_API_KEY and settings.LIVEKIT_API_SECRET)


def room_name(subject_id) -> str:
    return f"subject-{subject_id}"


def _b64(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def make_token(user: User, room: str, identity: str, *, now: float | None = None) -> str:
    issued = int(now if now is not None else time.time())
    header = {"alg": "HS256", "typ": "JWT"}
    claims = {
        "iss": settings.LIVEKIT_API_KEY, "sub": identity, "name": user.full_name or user.email,
        "nbf": issued, "exp": issued + TOKEN_TTL_SECONDS,
        "video": {"room": room, "roomJoin": True, "canPublish": True, "canSubscribe": True, "canPublishData": True},
    }
    signing = ".".join(_b64(json.dumps(part, separators=(",", ":")).encode()) for part in (header, claims))
    sig = hmac.new(settings.LIVEKIT_API_SECRET.encode(), signing.encode(), hashlib.sha256).digest()
    return f"{signing}.{_b64(sig)}"


def new_identity(user: User) -> str:
    """One identity per join: LiveKit evicts a second connection that reuses an identity."""
    return f"user-{user.id}-{secrets.token_hex(3)}"
