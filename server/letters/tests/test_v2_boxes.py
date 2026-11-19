"""Letters v2: workspace subject, labels, inbox/outbox/archive boxes and advanced search."""
from letters.tests.conftest import *  # noqa: F401,F403  (world, dev, PIN, BODY)
from letters.models import Letter
from workspace.models import Subject


def publish(world, **kw):
    letter = world.create(**kw)
    for s in world.signers:
        assert world.sign(s, letter["id"]).status_code == 200
    return letter


def ids(resp):
    assert resp.status_code == 200, resp.content
    return [x["id"] for x in resp.data]


# --- subject and labels ----------------------------------------------------------------------------------------


def test_new_letter_has_a_subject_with_module_letters(world):
    letter = world.create(send=False)
    subject = Subject.objects.get(pk=letter["subject_id"])
    assert (subject.module, subject.kind) == ("letters", "letter")
    assert Letter.objects.get(pk=letter["id"]).subject_id == subject.id


def test_labels_work_on_letters_and_stay_per_caller(world):
    letter = world.create(visibility="public", mode="now")
    org = world.boss.call("post", "/labels", {"name": "Urgent", "color": 1, "scope": "org"}).data
    mine = world.alice_d.call("post", "/labels", {"name": "Mine", "color": 2, "scope": "personal"}).data
    resp = world.alice_d.call("put", f"/subjects/{letter['subject_id']}/labels", {"label_ids": [org["id"], mine["id"]]})
    assert resp.status_code == 200, resp.content
    assert sorted(resp.data["label_ids"]) == sorted([org["id"], mine["id"]])
    seen_by_alice = world.alice_d.call("get", f"/letters/{letter['id']}").data
    assert sorted(seen_by_alice["label_ids"]) == sorted([org["id"], mine["id"]])
    seen_by_viewer = world.dev(world.viewer).call("get", f"/letters/{letter['id']}").data
    assert seen_by_viewer["label_ids"] == [org["id"]]  # the personal label is private to alice


def test_labels_refused_on_invisible_letter(world):
    letter = world.create(visibility="private")  # outsider is not a participant
    org = world.boss.call("post", "/labels", {"name": "Urgent", "color": 1, "scope": "org"}).data
    resp = world.dev(world.outsider).call("put", f"/subjects/{letter['subject_id']}/labels", {"label_ids": [org["id"]]})
    assert resp.status_code == 404


def test_comments_and_seen_by_use_the_letter_rules(world):
    letter = world.create(visibility="private", viewers=[world.viewer])
    sid = letter["subject_id"]
    assert world.dev(world.outsider).call("get", f"/subjects/{sid}/comments").status_code == 404
    posted = world.dev(world.signers[0]).call("post", f"/subjects/{sid}/comments", {"body": {"text": "ok"}})
    assert posted.status_code == 201, posted.content
    assert world.alice_d.call("post", f"/subjects/{sid}/seen").status_code == 204


# --- boxes -----------------------------------------------------------------------------------------------------


def test_inbox_outbox_archive(world):
    letter = world.create(visibility="private", viewers=[world.viewer])
    draft = world.create(send=False)
    lid = letter["id"]
    alice, signer, viewer = world.alice_d, world.dev(world.signers[0]), world.dev(world.viewer)
    assert ids(alice.call("get", "/letters?box=outbox")) == [draft["id"], lid]
    assert ids(alice.call("get", "/letters?box=inbox")) == []
    assert ids(signer.call("get", "/letters?box=inbox")) == [lid]
    assert ids(signer.call("get", "/letters?box=outbox")) == []
    assert ids(viewer.call("get", "/letters?box=inbox")) == []  # after_sign: not shown to viewers yet
    for s in world.signers:
        world.sign(s, lid)
    assert ids(viewer.call("get", "/letters?box=inbox")) == [lid]

    done = signer.call("post", f"/letters/{lid}/archive", {"archived": True})
    assert done.status_code == 200 and done.data["archived"] is True
    assert ids(signer.call("get", "/letters?box=inbox")) == []
    assert ids(signer.call("get", "/letters?box=archive")) == [lid]
    assert lid in ids(signer.call("get", "/letters?box=all"))
    assert ids(viewer.call("get", "/letters?box=inbox")) == [lid]  # archive is per user
    signer.call("post", f"/letters/{lid}/archive", {"archived": False})
    assert ids(signer.call("get", "/letters?box=inbox")) == [lid]


def test_default_box_is_all_and_bad_box_is_rejected(world):
    letter = world.create()
    assert ids(world.alice_d.call("get", "/letters")) == [letter["id"]]
    assert world.alice_d.call("get", "/letters?box=nope").status_code == 422


def test_archive_needs_visibility(world):
    letter = world.create(visibility="private")
    resp = world.dev(world.outsider).call("post", f"/letters/{letter['id']}/archive", {"archived": True})
    assert resp.status_code == 404


# --- search ----------------------------------------------------------------------------------------------------


def test_search_scoping_and_filters(world):
    public = publish(world, visibility="public")
    private = world.create(visibility="private")
    outsider = world.dev(world.outsider)
    found = ids(outsider.call("get", "/letters/search?q=Budget"))
    assert found == [public["id"]]  # the private letter never shows, not even through its title
    assert sorted(ids(world.alice_d.call("get", "/letters/search?q=Budget"))) == sorted([public["id"], private["id"]])
    assert ids(world.alice_d.call("get", "/letters/search?status=published")) == [public["id"]]
    assert ids(world.alice_d.call("get", "/letters/search?signer=s1@corp")) != []
    assert ids(world.alice_d.call("get", "/letters/search?creator=nobody")) == []
    assert ids(world.alice_d.call("get", "/letters/search?from=2999-01-01")) == []


def test_search_body_text_only_for_visible_letters(world):
    body = {"text": "confidential merger plan", "attachments": []}
    mine = world.alice_d.call("post", "/letters", {**world.body(visibility="private"), "body": body}).data
    assert ids(world.alice_d.call("get", "/letters/search?q=merger")) == [mine["id"]]
    assert ids(world.dev(world.outsider).call("get", "/letters/search?q=merger")) == []


def test_search_by_label_and_person(world):
    letter = world.create(visibility="public", mode="now")
    mine = world.alice_d.call("post", "/labels", {"name": "Contracts", "color": 1, "scope": "personal"}).data
    world.alice_d.call("put", f"/subjects/{letter['subject_id']}/labels", {"label_ids": [mine["id"]]})
    assert ids(world.alice_d.call("get", f"/letters/search?label={mine['id']}")) == [letter["id"]]
    assert ids(world.alice_d.call("get", "/letters/search?q=contracts")) == [letter["id"]]
    other = world.dev(world.viewer)  # cannot use alice's personal label
    assert ids(other.call("get", f"/letters/search?label={mine['id']}")) == []
    assert ids(other.call("get", "/letters/search?q=alice@corp")) == [letter["id"]]


def test_brief_shows_number_label_and_counts(world):
    letter = world.create()
    brief = world.alice_d.call("get", "/letters").data[0]
    assert brief["number_label"] == "" and brief["referral_count"] == 0 and brief["label_ids"] == []
    assert brief["subject_id"] == letter["subject_id"]


def test_letter_triggers_survive_the_v2_migration(world):
    import pytest
    from django.db import DatabaseError

    letter = world.create()
    with pytest.raises(DatabaseError):
        Letter.objects.filter(pk=letter["id"]).delete()
    with pytest.raises(DatabaseError):
        Letter.objects.filter(pk=letter["id"]).update(title="changed")
