import base64
import hashlib
import hmac
import json

import pytest


@pytest.fixture(autouse=True)
def _modules(brand_dir):
    brand_dir()


@pytest.fixture
def crew(make_user, login):
    grants = ("task.create", "project.create")
    out = type("Crew", (), {})()
    for name in ("ann", "bob"):
        setattr(out, f"{name}_d", login(make_user(f"{name}@corp.test", grants=grants)))
    return out


def _decode(token: str) -> dict:
    head, body, sig = token.split(".")
    pad = "=" * (-len(body) % 4)
    return json.loads(base64.urlsafe_b64decode(body + pad))


def test_not_configured_is_503_and_config_says_so(crew, settings):
    settings.LIVEKIT_URL = ""
    assert crew.ann_d.call("get", "/video/config").data == {"enabled": False}
    task = crew.ann_d.call("post", "/tasks", {"title": "Sync"}).data
    assert crew.ann_d.call("post", "/video/join", {"subject_id": task["subject_id"]}).status_code == 503


def test_join_signs_a_room_token_for_people_who_can_see_the_subject(crew, settings):
    settings.LIVEKIT_URL, settings.LIVEKIT_API_KEY, settings.LIVEKIT_API_SECRET = "wss://m.test", "key", "secret"
    task = crew.ann_d.call("post", "/tasks", {"title": "Sync"}).data
    assert crew.ann_d.call("get", "/video/config").data == {"enabled": True}
    got = crew.ann_d.call("post", "/video/join", {"subject_id": task["subject_id"]})
    assert got.status_code == 200, got.content
    assert got.data["url"] == "wss://m.test" and got.data["room"] == f"subject-{task['subject_id']}"
    head, body, sig = got.data["token"].split(".")
    want = hmac.new(b"secret", f"{head}.{body}".encode(), hashlib.sha256).digest()
    assert base64.urlsafe_b64decode(sig + "=" * (-len(sig) % 4)) == want
    claims = _decode(got.data["token"])
    assert claims["iss"] == "key" and claims["video"]["room"] == got.data["room"] and claims["video"]["roomJoin"]
    assert claims["sub"] == got.data["identity"]


def test_outsiders_cannot_join_a_private_subject(crew, settings):
    settings.LIVEKIT_URL, settings.LIVEKIT_API_KEY, settings.LIVEKIT_API_SECRET = "wss://m.test", "key", "secret"
    task = crew.ann_d.call("post", "/tasks", {"title": "Private"}).data
    assert crew.bob_d.call("post", "/video/join", {"subject_id": task["subject_id"]}).status_code == 404
