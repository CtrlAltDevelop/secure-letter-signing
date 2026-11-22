import pytest
from django.db import connection, transaction

from letters.models import Letter
from letters.tests.conftest import BODY, PIN


def test_signers_cannot_see_or_touch_a_draft(world):
    lid = world.create(send=False)["id"]
    signer = world.dev(world.signers[0])
    assert signer.call("get", f"/letters/{lid}").status_code == 404
    assert signer.call("post", f"/letters/{lid}/opened").status_code == 404
    assert lid not in {x["id"] for x in signer.call("get", "/letters").data}
    assert world.boss.call("get", "/letters/admin").data == []  # the manager does not see drafts either


def test_a_draft_cannot_be_signed(world):
    lid = world.create(send=False)["id"]
    assert world.sign(world.signers[0], lid).status_code == 404  # drafts are invisible to signers


def test_parent_is_bound_into_the_seal(world):
    parent = world.create()["id"]
    child = world.create(parent=parent)["id"]
    assert world.sign(world.signers[0], child).status_code == 200
    payload = world.alice_d.call("get", f"/letters/{child}").data["signatures"][0]["payload"]
    assert payload["parentId"] == parent


def test_limits_and_bad_input_do_not_crash(world):
    assert world.alice_d.call("get", "/letters?limit=-5&offset=-1").status_code == 200
    data = world.body()
    data["body"] = {"text": "x" * 2_000_001}
    assert world.alice_d.call("post", "/letters", data).status_code == 413
    lid = world.create()["id"]
    d = world.dev(world.signers[0])
    assert d.call("post", f"/letters/{lid}/sign", {"decision": "maybe", "pin": PIN}).status_code == 422
    assert d.call("post", f"/letters/{lid}/sign", {"decision": "approved", "note": "n" * 2001, "pin": PIN}).status_code == 422
    assert d.call("post", f"/letters/{lid}/sign", {"decision": "approved"}).status_code == 422


def test_removed_key_endpoints_are_gone(world):
    d = world.alice_d
    auth = {"HTTP_AUTHORIZATION": f"Bearer {d.token}"}
    lid = world.create()["id"]
    assert d.api.client.get("/api/keys", **auth).status_code == 404
    assert d.api.client.get("/api/letters/rewrap-needed", **auth).status_code == 404
    assert d.api.client.post(f"/api/letters/{lid}/wraps", [], content_type="application/json", **auth).status_code == 404


def test_sent_letter_body_is_immutable_in_the_database(world):
    lid = world.create()["id"]
    with pytest.raises(Exception, match="immutable"), transaction.atomic():
        Letter.objects.filter(pk=lid).update(title="changed")
    with pytest.raises(Exception, match="immutable"), transaction.atomic():
        Letter.objects.filter(pk=lid).update(body={"v": 3, "ct": "swapped"})
    with connection.cursor() as cur:
        cur.execute("UPDATE letters_letter SET unlisted = 0")  # other fields can still change


def test_a_draft_body_can_still_be_edited(world):
    lid = world.create(send=False)["id"]
    edited = world.body() | {"body": BODY | {"text": "second version"}}
    assert world.alice_d.call("put", f"/letters/{lid}", edited).status_code == 200
    assert world.alice_d.call("get", f"/letters/{lid}").data["body"]["text"] == "second version"


def test_letter_no_continues_from_max_and_never_repeats(world):
    first = world.create(send=False)
    second = world.create(send=False)
    assert second["no"] == first["no"] + 1
    Letter.objects.filter(pk=second["id"]).update(no=500)  # the counter must never fall below the stored max
    assert world.create(send=False)["no"] == 501


def test_attachment_digest_is_sealed_and_upload_quota_is_enforced(world, settings, tmp_path):
    import hashlib

    from django.core.files.uploadedfile import SimpleUploadedFile

    settings.MEDIA_ROOT = tmp_path
    lid = world.create(send=False)["id"]
    d = world.alice_d
    data = b"%PDF-1.4 sealed"

    def up(content):
        return d.api.client.post(f"/api/letters/{lid}/attachments", {
            "content_type": "application/pdf", "file": SimpleUploadedFile("x.pdf", content)},
            HTTP_AUTHORIZATION=f"Bearer {d.token}")

    aid = up(data).json()["id"]
    settings.MAX_USER_UPLOAD_BYTES_PER_DAY = len(data) + 1
    assert up(data).status_code == 429
    d.call("post", f"/letters/{lid}/send")
    assert world.sign(world.signers[0], lid).status_code == 200
    payload = d.call("get", f"/letters/{lid}").data["signatures"][0]["payload"]
    assert payload["attachments"] == [{"id": aid, "size": len(data), "sha256": hashlib.sha256(data).hexdigest()}]
