import pytest
from django.db import connection, transaction

from letters.models import Letter
from letters.tests.test_letters import world  # noqa: F401


def test_signers_cannot_see_or_touch_a_draft(world):
    lid = world.create(send=False)["id"]
    signer = world.dev(world.signers[0])
    assert signer.call("get", f"/letters/{lid}").status_code == 404
    assert signer.call("post", f"/letters/{lid}/opened").status_code == 404
    assert lid not in {x["id"] for x in signer.call("get", "/letters").data}
    assert world.boss.call("get", "/letters/admin").data == []  # the manager does not see drafts either


def test_a_planted_wrap_cannot_block_the_key_owner(world):
    lid = world.create()["id"]
    victim = world.dev(world.signers[1])
    attacker = world.dev(world.signers[0])
    # existing wraps cannot be overwritten by someone else...
    forged = attacker.call("post", f"/letters/{lid}/wraps", [{"key_id": victim.key_id, "wrap": {"ct": "junk"}}])
    assert forged.status_code == 200
    mine = victim.call("get", f"/letters/{lid}").data["my_wraps"]
    assert mine[0]["wrap"] == {"ct": "w"}
    # ...but the owner may replace their own wrap
    victim.call("post", f"/letters/{lid}/wraps", [{"key_id": victim.key_id, "wrap": {"ct": "fixed"}}])
    assert victim.call("get", f"/letters/{lid}").data["my_wraps"][0]["wrap"] == {"ct": "fixed"}


def test_parent_is_bound_into_the_signature(world):
    parent = world.create()["id"]
    child = world.create(parent=parent)["id"]
    d = world.dev(world.signers[0])
    letter = d.call("get", f"/letters/{child}").data
    payload = d.decision_payload(letter) | {"parentId": None}
    resp = d.call("post", f"/letters/{child}/sign", {"key_id": d.key_id, "payload": payload, "signature": d.sign(payload)})
    assert resp.status_code == 422


def test_limits_and_bad_input_do_not_crash(world):
    assert world.alice_d.call("get", "/letters?limit=-5&offset=-1").status_code == 200
    data = world.body()
    data["body"] = {"iv": "aXY=", "ct": "x" * 2_000_001}
    assert world.alice_d.call("post", "/letters", data).status_code == 413
    lid = world.create()["id"]
    d = world.dev(world.signers[0])
    assert d.call("post", f"/letters/{lid}/sign", {"key_id": d.key_id, "payload": {}, "signature": "x"}).status_code == 422


def test_company_rotation_must_cover_every_active_key_and_never_overwrites(world):
    boss = world.boss
    everyone = [{"key_id": d.key_id, "wrap": {"ct": "a"}} for d in world.d.values()]
    assert boss.call("post", "/keys/company", {"version": 2, "wraps": everyone[:2]}).status_code == 422
    assert boss.call("post", "/keys/company", {"version": 2, "wraps": everyone}).status_code == 200
    again = [{"key_id": everyone[0]["key_id"], "wrap": {"ct": "evil"}}]
    boss.call("post", "/keys/company", {"version": 2, "wraps": again})
    from keys.models import CompanyKeyWrap

    assert CompanyKeyWrap.objects.get(version_id=2, key_id=everyone[0]["key_id"]).wrap == {"ct": "a"}


def test_sent_letter_body_is_immutable_in_the_database(world):
    lid = world.create()["id"]
    with pytest.raises(Exception, match="immutable"), transaction.atomic():
        Letter.objects.filter(pk=lid).update(title="changed")
    with connection.cursor() as cur:
        cur.execute("UPDATE letters_letter SET unlisted = 0")  # other fields can still change
