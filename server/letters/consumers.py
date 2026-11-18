"""WebSocket: /ws/?token=<access token>. Live letter events + notifications, with catch-up by event id."""
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from django.core import signing
from asgiref.sync import sync_to_async

from accounts.auth import ACCESS_MAX_AGE
from accounts.models import Session
from accounts.notify import user_group

from .api import replay_events

AUTH_FAILED = 4401


def _live_session(session_id: str):
    return Session.objects.select_related("user").filter(
        pk=session_id, revoked_at__isnull=True, user__is_active=True).first()


class LetterConsumer(AsyncJsonWebsocketConsumer):
    session_id: str | None = None
    user = None

    async def connect(self):
        token = self.scope["query_string"].decode().partition("token=")[2].split("&")[0]
        try:
            self.session_id = signing.loads(token, salt="access", max_age=ACCESS_MAX_AGE)["s"]
        except signing.BadSignature:
            return await self.close(code=AUTH_FAILED)
        session = await sync_to_async(_live_session)(self.session_id)
        if session is None:
            return await self.close(code=AUTH_FAILED)
        self.user = session.user
        await self.channel_layer.group_add(user_group(self.user.id), self.channel_name)
        await self.accept()

    async def disconnect(self, code):
        if self.user is not None:
            await self.channel_layer.group_discard(user_group(self.user.id), self.channel_name)

    async def receive_json(self, content, **kwargs):
        """Client sends {"after": <last event id it has>} after (re)connecting to catch up."""
        if not await self._still_valid():
            return
        after = content.get("after") if isinstance(content, dict) else None
        if isinstance(after, int) and after >= 0:
            for event in await sync_to_async(replay_events)(self.user, after):
                await self.send_json(event)

    async def event(self, message):
        """Group message from the server. A revoked session stops receiving and is closed."""
        if await self._still_valid():
            await self.send_json(message["event"])

    async def _still_valid(self) -> bool:
        if await sync_to_async(_live_session)(self.session_id) is None:
            await self.close(code=AUTH_FAILED)
            return False
        return True
