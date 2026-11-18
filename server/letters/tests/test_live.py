from asgiref.sync import async_to_sync, sync_to_async
from channels.testing import WebsocketCommunicator

from accounts.models import Session
from config.asgi import application


def connect(token: str) -> WebsocketCommunicator:
    return WebsocketCommunicator(application, f"/ws/?token={token}", headers=[(b"origin", b"http://localhost")])


def test_signature_on_one_device_reaches_another_live_and_catch_up_works(world, dev, django_capture_on_commit_callbacks):
    lid = world.create(send=False)["id"]
    laptop_token = dev(world.alice, "laptop").token

    async def scenario():
        ws = connect(laptop_token)
        connected, _ = await ws.connect()
        assert connected
        await ws.send_json_to({"after": 0})  # nothing yet
        assert await ws.receive_nothing(timeout=0.2)

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


def test_sign_request_frames_go_to_the_right_sessions_only(world, dev, django_capture_on_commit_callbacks):
    user = world.signers[0]
    laptop, phone, tablet = dev(user, "laptop"), dev(user, "phone", biometric=True), dev(user, "tablet", biometric=True)
    lid = world.create()["id"]

    def call(who, method, path, data=None):
        with django_capture_on_commit_callbacks(execute=True):
            return who.call(method, path, data)

    async def run(who, *args):
        return await sync_to_async(call, thread_sensitive=True)(who, *args)

    async def next_request_frame(ws):
        """Next sign_request* frame; `letter` frames (shared user group) are skipped."""
        while True:
            frame = await ws.receive_json_from(timeout=2)
            if frame["type"].startswith("sign_request"):
                return frame

    async def no_request_frame(ws):
        while not await ws.receive_nothing(timeout=0.2):
            assert (await ws.receive_json_from(timeout=1))["type"] == "letter"

    async def scenario():
        sockets = {}
        for name, d in {"laptop": laptop, "phone": phone, "tablet": tablet}.items():
            sockets[name] = connect(d.token)
            assert (await sockets[name].connect())[0]
        resp = await run(laptop, "post", f"/letters/{lid}/sign-requests",
                         {"decision": "approved", "note": "n", "approver_session_id": phone.session_id})
        rid = resp.data["id"]
        frame = await next_request_frame(sockets["phone"])
        assert frame["type"] == "sign_request" and frame["request"]["id"] == rid
        assert frame["request"]["status"] == "pending" and frame["request"]["requester_device_name"] == "laptop"
        assert "event_id" not in frame
        await no_request_frame(sockets["laptop"])  # requester gets updates, not the request
        await no_request_frame(sockets["tablet"])  # another session of the user: nothing
        await run(phone, "post", f"/sign-requests/{rid}/approve")
        for name in ("laptop", "phone"):
            update = await next_request_frame(sockets[name])
            assert update["type"] == "sign_request_update" and update["request"]["status"] == "approved"
        await no_request_frame(sockets["tablet"])
        for ws in sockets.values():
            await ws.disconnect()

    async_to_sync(scenario)()


async def next_request_frame(ws):
    """Next sign_request* frame; `letter` frames (shared user group) are skipped."""
    while True:
        frame = await ws.receive_json_from(timeout=2)
        if frame["type"].startswith("sign_request"):
            return frame


def test_decline_and_cancel_push_updates_to_both_sessions(world, dev, django_capture_on_commit_callbacks):
    user = world.signers[0]
    laptop, phone = dev(user, "laptop"), dev(user, "phone", biometric=True)
    lid = world.create()["id"]

    def call(who, method, path, data=None):
        with django_capture_on_commit_callbacks(execute=True):
            return who.call(method, path, data)

    async def run(who, *args):
        return await sync_to_async(call, thread_sensitive=True)(who, *args)

    async def scenario():
        lap, pho = connect(laptop.token), connect(phone.token)
        await lap.connect()
        await pho.connect()
        rid = (await run(laptop, "post", f"/letters/{lid}/sign-requests", {
            "decision": "approved", "note": "", "approver_session_id": phone.session_id})).data["id"]
        await next_request_frame(pho)
        await run(phone, "post", f"/sign-requests/{rid}/decline")
        for ws in (lap, pho):
            assert (await next_request_frame(ws))["request"]["status"] == "declined"
        rid2 = (await run(laptop, "post", f"/letters/{lid}/sign-requests", {
            "decision": "approved", "note": "", "approver_session_id": phone.session_id})).data["id"]
        await next_request_frame(pho)
        await run(laptop, "post", f"/sign-requests/{rid2}/cancel")
        for ws in (lap, pho):
            assert (await next_request_frame(ws))["request"]["status"] == "cancelled"
        await lap.disconnect()
        await pho.disconnect()

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
