import pytest
from asgiref.sync import async_to_sync
from channels.testing import WebsocketCommunicator

from accounts.models import Session
from config.asgi import application
from letters.tests.test_letters import World  # noqa: F401  (fixture below uses it)
from letters.tests.test_letters import world  # noqa: F401


def connect(token: str) -> WebsocketCommunicator:
    return WebsocketCommunicator(application, f"/ws/?token={token}", headers=[(b"origin", b"http://localhost")])


def test_signature_on_one_device_reaches_another_live_and_catch_up_works(world, django_capture_on_commit_callbacks):
    lid = world.create(send=False)["id"]
    laptop_token = world.alice_d.api.login(world.alice.email, device="laptop")["access"]

    async def scenario():
        ws = connect(laptop_token)
        connected, _ = await ws.connect()
        assert connected
        await ws.send_json_to({"after": 0})  # nothing yet
        assert await ws.receive_nothing(timeout=0.2)
        from asgiref.sync import sync_to_async

        def send():
            with django_capture_on_commit_callbacks(execute=True):  # tests never commit, so run the hooks
                world.alice_d.call("post", f"/letters/{lid}/send")

        await sync_to_async(send, thread_sensitive=True)()
        live = await ws.receive_json_from(timeout=2)
        assert live["kind"] == "sent" and live["title"] == "Budget 2027"
        await ws.disconnect()
        again = connect(laptop_token)
        await again.connect()
        await again.send_json_to({"after": 0})  # reconnect catch-up by event id
        replay = await again.receive_json_from(timeout=2)
        assert replay["event_id"] == live["event_id"]
        await again.disconnect()

    async_to_sync(scenario)()


def test_revoked_session_is_refused_and_bad_token_rejected(world):
    token = world.alice_d.token
    Session.objects.filter(user=world.alice).update(revoked_at="2020-01-01T00:00:00Z")

    async def scenario():
        denied, code = await connect(token).connect()
        assert not denied and code == 4401
        denied, code = await connect("garbage").connect()
        assert not denied and code == 4401

    async_to_sync(scenario)()
