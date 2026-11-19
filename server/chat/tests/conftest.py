from types import SimpleNamespace

import pytest
from django.core.files.uploadedfile import SimpleUploadedFile

from workspace.tests.conftest import *  # noqa: F401,F403  (api, make_user, manager, login, brand_dir)

PNG = b"\x89PNG\r\n\x1a\n" + b"0" * 32
GRANTS = ("chat.create_group", "task.create", "project.create", "customer.create")


@pytest.fixture(autouse=True)
def _all_modules(brand_dir):
    brand_dir()


@pytest.fixture
def team(make_user, login):
    people = {name: make_user(f"{name}@corp.test", grants=GRANTS) for name in ("ann", "bob", "cy", "dee")}
    out = SimpleNamespace(**{n: login(u) for n, u in people.items()})
    out.users = SimpleNamespace(**people)
    return out


def make_group(who, *others, kind="group", **over):
    body = {"kind": kind, "name": "Team", "member_ids": [o.id for o in others], **over}
    resp = who.call("post", "/chat/conversations", body)
    assert resp.status_code == 201, resp.content
    return resp.data


def say(who, conv, text="hello", **over):
    resp = who.call("post", f"/chat/conversations/{conv['id']}/messages", {"text": text, **over})
    assert resp.status_code == 201, resp.content
    return resp.data


def upload(who, subject_id, content_type="image/png", data=PNG):
    resp = who.api.client.post(f"/api/subjects/{subject_id}/files", {
        "file": SimpleUploadedFile("f.bin", data, content_type=content_type), "content_type": content_type},
        HTTP_AUTHORIZATION=f"Bearer {who.token}")
    resp.data = resp.json() if resp.content else None
    return resp
