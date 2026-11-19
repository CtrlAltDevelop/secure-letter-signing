import json
import time

import pytest
from django.db import transaction
from django.db.utils import DatabaseError

from notes.models import Note
from workspace.tests.conftest import *  # noqa: F401,F403  (api, make_user, manager, login, brand_dir)

PNG = b"\x89PNG\r\n\x1a\n" + b"0" * 32


@pytest.fixture(autouse=True)
def _all_modules(brand_dir):
    brand_dir()


@pytest.fixture
def me(make_user, login):
    return login(make_user("me@corp.test"))


@pytest.fixture
def other(make_user, login):
    return login(make_user("other@corp.test"))


def _note(me, **over):
    resp = me.call("post", "/notes", {"title": "Shopping", "body": {"text": "milk and eggs"}, **over})
    assert resp.status_code == 201, resp.content
    return resp.data


def test_create_encrypts_body_and_returns_out(me):
    data = _note(me, color=3, checklist=["a", "b"])
    assert data["color"] == 3 and data["pinned"] is False and data["archived"] is False
    assert [i["text"] for i in data["checklist_items"]] == ["a", "b"] and data["body"] == {"text": "milk and eggs"}
    row = Note.objects.get(pk=data["id"])
    assert "milk" not in json.dumps(row.body) and row.subject.module == "notes"
    assert me.call("post", "/notes", {"color": 16}).status_code == 422


def test_nobody_else_sees_a_note(me, other, manager, login):
    data = _note(me)
    boss = login(manager)
    for who in (other, boss):
        assert who.call("get", f"/notes/{data['id']}").status_code == 404
        assert who.call("patch", f"/notes/{data['id']}", {"title": "x"}).status_code == 404
        assert who.call("post", f"/notes/{data['id']}/pin", {"pinned": True}).status_code == 404
        assert who.call("post", f"/notes/{data['id']}/archive").status_code == 404
        assert who.call("post", f"/notes/{data['id']}/checklist", {"text": "x"}).status_code == 404
        assert who.call("get", f"/subjects/{data['subject_id']}/comments").status_code == 404
        assert who.call("get", f"/subjects/{data['subject_id']}/files").status_code == 404
        assert who.call("get", "/notes").data == []


def test_patch_and_checklist_ops(me):
    data = _note(me, checklist=["a", "b"])
    nid = data["id"]
    assert me.call("patch", f"/notes/{nid}", {"title": "New", "body": {"text": "z"}}).data["body"] == {"text": "z"}
    added = me.call("post", f"/notes/{nid}/checklist", {"text": "c"}).data
    ids = [i["id"] for i in added["checklist_items"]]
    done = me.call("patch", f"/notes/{nid}/checklist/{ids[0]}", {"done": True}).data
    assert done["checklist_items"][0]["done"] is True
    ordered = me.call("put", f"/notes/{nid}/checklist/order", {"item_ids": ids[::-1]}).data
    assert [i["id"] for i in ordered["checklist_items"]] == ids[::-1]
    assert me.call("put", f"/notes/{nid}/checklist/order", {"item_ids": ids[:2]}).status_code == 422
    gone = me.call("patch", f"/notes/{nid}/checklist/{ids[1]}", {"active": False}).data
    assert ids[1] not in [i["id"] for i in gone["checklist_items"]]


def test_pinned_first_then_updated_and_archive_filter(me):
    first, second, third = (_note(me, title=t) for t in ("one", "two", "three"))
    time.sleep(0.01)
    me.call("post", f"/notes/{first['id']}/pin", {"pinned": True})
    titles = [n["title"] for n in me.call("get", "/notes").data]
    assert titles == ["one", "three", "two"]
    me.call("patch", f"/notes/{second['id']}", {"title": "two!"})
    assert [n["title"] for n in me.call("get", "/notes").data] == ["one", "two!", "three"]
    assert [n["title"] for n in me.call("get", "/notes?pinned=true").data] == ["one"]
    assert me.call("post", f"/notes/{third['id']}/archive").data["archived"] is True
    assert "three" not in [n["title"] for n in me.call("get", "/notes").data]
    assert [n["title"] for n in me.call("get", "/notes?archived=true").data] == ["three"]
    assert me.call("post", f"/notes/{third['id']}/archive", {"archived": False}).data["archived"] is False


def test_search_and_label_filter(me):
    a, b = _note(me, title="Alpha plan"), _note(me, title="Beta", checklist=["call bob"])
    assert [n["title"] for n in me.call("get", "/notes?q=alpha").data] == ["Alpha plan"]
    assert [n["title"] for n in me.call("get", "/notes?q=bob").data] == ["Beta"]
    label = me.call("post", "/labels", {"name": "work", "scope": "personal"}).data
    assert me.call("put", f"/subjects/{b['subject_id']}/labels", {"label_ids": [label["id"]]}).status_code == 200
    got = me.call("get", f"/notes?label={label['id']}").data
    assert [n["title"] for n in got] == ["Beta"] and got[0]["label_ids"] == [label["id"]]
    assert a["id"] not in [n["id"] for n in got]


def _upload(me, subject_id, content_type="image/png"):
    from django.core.files.uploadedfile import SimpleUploadedFile

    return me.api.client.post(f"/api/subjects/{subject_id}/files", {
        "file": SimpleUploadedFile("p.png", PNG, content_type=content_type), "content_type": content_type},
        HTTP_AUTHORIZATION=f"Bearer {me.token}")


def test_only_images_and_at_most_ten(me):
    note = _note(me)
    assert _upload(me, note["subject_id"], "application/pdf").status_code == 422
    for _ in range(10):
        assert _upload(me, note["subject_id"]).status_code == 201
    assert _upload(me, note["subject_id"]).status_code == 422
    assert me.call("get", f"/notes/{note['id']}").data["image_count"] == 10


def test_module_off_and_no_hard_delete(me, brand_dir):
    note = _note(me)
    with pytest.raises(DatabaseError), transaction.atomic():
        Note.objects.filter(pk=note["id"]).delete()
    brand_dir(modules=["tasks"])
    assert me.call("get", "/notes").status_code == 404
