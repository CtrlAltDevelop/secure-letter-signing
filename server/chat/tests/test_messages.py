import json

import pytest
from django.utils import timezone

from accounts.models import Notification
from chat.models import Message, MessageRead

from .conftest import make_group, say, upload


@pytest.fixture
def grp(team):
    u = team.users
    return make_group(team.ann, u.bob, u.cy)


def test_post_encrypts_and_seq_is_gap_free(team, grp):
    first = say(team.ann, grp, "**bold** and *it*")
    assert first["seq"] == 1 and first["text"] == "**bold** and *it*" and first["edited"] is False
    assert "bold" not in json.dumps(Message.objects.get(pk=first["id"]).body)
    bad = team.bob.call("post", f"/chat/conversations/{grp['id']}/messages", {"text": "  "})
    assert bad.status_code == 422
    seqs = [say(team.bob, grp, f"m{i}")["seq"] for i in range(3)]
    assert seqs == [2, 3, 4]
    rows = team.ann.call("get", f"/chat/conversations/{grp['id']}/messages").data
    assert [m["seq"] for m in rows] == [1, 2, 3, 4]


def test_outsider_cannot_post(team, grp):
    resp = team.dee.call("post", f"/chat/conversations/{grp['id']}/messages", {"text": "x"})
    assert resp.status_code == 404


def test_paging_and_around_date(team, grp):
    for i in range(6):
        say(team.ann, grp, f"m{i}")
    cid = grp["id"]
    assert [m["seq"] for m in team.bob.call("get", f"/chat/conversations/{cid}/messages?limit=2").data] == [5, 6]
    assert [m["seq"] for m in team.bob.call("get", f"/chat/conversations/{cid}/messages?before_seq=5&limit=2").data] == [3, 4]
    assert [m["seq"] for m in team.bob.call("get", f"/chat/conversations/{cid}/messages?after_seq=4").data] == [5, 6]
    old = timezone.now() - timezone.timedelta(days=10)
    Message.objects.filter(conversation_id=cid, seq__lte=2).update(created_at=old)
    day = (timezone.now() - timezone.timedelta(days=3)).date().isoformat()
    jump = team.bob.call("get", f"/chat/conversations/{cid}/messages?around_date={day}&limit=2").data
    assert [m["seq"] for m in jump] == [3, 4]
    oldest = old.date().isoformat()
    assert team.bob.call("get", f"/chat/conversations/{cid}/messages?around_date={oldest}&limit=1").data[0]["seq"] == 1
    assert team.bob.call("get", f"/chat/conversations/{cid}/messages?around_date=2999-01-01").data == []
    assert team.bob.call("get", f"/chat/conversations/{cid}/messages?around_date=nope").status_code == 422


def test_unread_counts_and_read_receipts(team, grp):
    for i in range(3):
        say(team.ann, grp, f"m{i}")
    mine = team.bob.call("get", "/chat/conversations?mine=true").data[0]
    assert mine["unread"] == 3 and mine["last_message_preview"] == "m2" and mine["last_message_at"]
    assert team.ann.call("get", "/chat/conversations").data[0]["unread"] == 0  # own messages never count
    assert team.bob.call("get", "/chat/unread").data["total"] == 3
    done = team.bob.call("post", f"/chat/conversations/{grp['id']}/read", {"seq": 2})
    assert done.data == {"last_read_seq": 2}
    assert team.bob.call("get", "/chat/unread").data["total"] == 1
    assert team.bob.call("post", f"/chat/conversations/{grp['id']}/read", {"seq": 1}).data["last_read_seq"] == 2
    assert team.bob.call("post", f"/chat/conversations/{grp['id']}/read", {"seq": 99}).data["last_read_seq"] == 3
    assert team.bob.call("get", "/chat/unread").data == {"total": 0, "mentions": 0, "conversations": []}
    first = Message.objects.get(conversation_id=grp["id"], seq=1)
    assert MessageRead.objects.filter(message=first, user=team.users.bob).count() == 1
    seen = team.ann.call("get", f"/chat/messages/{first.id}/seen").data
    assert seen["tracked"] is True and [s["user"]["id"] for s in seen["seen"]] == [team.users.bob.id]
    assert team.bob.call("get", f"/chat/messages/{first.id}/seen").status_code == 403  # neither author nor admin
    assert team.cy.call("get", f"/chat/messages/{first.id}/seen").status_code == 403


def test_receipts_skipped_above_cap(team, grp, monkeypatch):
    from chat import messaging

    monkeypatch.setattr(messaging, "RECEIPT_CAP", 2)
    msg = say(team.ann, grp, "x")
    team.bob.call("post", f"/chat/conversations/{grp['id']}/read", {"seq": 1})
    assert MessageRead.objects.count() == 0
    assert team.ann.call("get", f"/chat/messages/{msg['id']}/seen").data == {"tracked": False, "seen": []}


def test_edit_and_delete_tombstone(team, grp):
    msg = say(team.bob, grp, "secret text")
    mid = msg["id"]
    assert team.ann.call("patch", f"/chat/messages/{mid}", {"text": "x"}).status_code == 403  # even an admin
    edited = team.bob.call("patch", f"/chat/messages/{mid}", {"text": "fixed"}).data
    assert edited["text"] == "fixed" and edited["edited"] is True and edited["edited_at"]
    assert team.dee.call("patch", f"/chat/messages/{mid}", {"text": "x"}).status_code == 404
    assert team.cy.call("delete", f"/chat/messages/{mid}").status_code == 403
    gone = team.ann.call("delete", f"/chat/messages/{mid}")  # conversation admin
    assert gone.status_code == 200 and gone.data["deleted"] is True and gone.data["text"] == ""
    assert Message.objects.get(pk=mid).body == {}
    assert team.bob.call("patch", f"/chat/messages/{mid}", {"text": "x"}).status_code == 409
    listed = team.cy.call("get", f"/chat/conversations/{grp['id']}/messages").data
    assert listed[0]["deleted"] is True and listed[0]["seq"] == 1
    own = say(team.cy, grp, "mine")
    assert team.cy.call("delete", f"/chat/messages/{own['id']}").status_code == 200


def test_reply_and_mentions_validated(team, grp):
    base = say(team.ann, grp, "question?")
    reply = say(team.bob, grp, "answer", reply_to_id=base["id"])
    assert reply["reply_to"]["id"] == base["id"] and reply["reply_to"]["preview"] == "question?"
    url = f"/chat/conversations/{grp['id']}/messages"
    assert team.bob.call("post", url, {"text": "x", "reply_to_id": 999999}).status_code == 422
    other = make_group(team.ann, team.users.bob, name="Other")
    foreign = say(team.ann, other, "elsewhere")
    assert team.bob.call("post", url, {"text": "x", "reply_to_id": foreign["id"]}).status_code == 422
    assert team.bob.call("post", url, {"text": "@dee", "mentions": [team.users.dee.id]}).status_code == 422
    ok = say(team.bob, grp, "@ann", mentions=[team.users.ann.id, team.users.ann.id])
    assert ok["mentions"] == [team.users.ann.id]


def test_mention_notifies_even_when_muted_without_text(team, grp):
    team.cy.call("post", f"/chat/conversations/{grp['id']}/mute", {"muted": True})
    say(team.ann, grp, "plain message")
    assert not Notification.objects.filter(user=team.users.cy, kind="chat.mention").exists()
    say(team.ann, grp, "top secret @cy", mentions=[team.users.cy.id, team.users.ann.id])
    rows = Notification.objects.filter(kind="chat.mention")
    assert [r.user_id for r in rows] == [team.users.cy.id]
    assert "secret" not in json.dumps([r.title for r in rows] + [r.data for r in rows])
    assert team.cy.call("get", "/chat/unread").data["mentions"] == 1
    mine = team.cy.call("get", "/chat/conversations").data[0]
    assert mine["mention_unread"] == 1 and mine["muted"] is True
    assert team.cy.call("get", "/chat/unread").data["total"] == 0  # muted chats stay out of the badge total


def test_pin_messages(team, grp):
    msg = say(team.bob, grp, "important")
    mid, cid = msg["id"], grp["id"]
    assert team.bob.call("post", f"/chat/messages/{mid}/pin").status_code == 403  # group: admins pin
    assert team.ann.call("post", f"/chat/messages/{mid}/pin").data["pinned"] is True
    assert team.ann.call("post", f"/chat/messages/{mid}/pin").status_code == 200  # idempotent
    assert [m["id"] for m in team.cy.call("get", f"/chat/conversations/{cid}/pins").data] == [mid]
    assert team.ann.call("delete", f"/chat/messages/{mid}/pin").data["pinned"] is False
    assert team.cy.call("get", f"/chat/conversations/{cid}/pins").data == []
    team.ann.call("post", f"/chat/messages/{mid}/pin")
    team.ann.call("delete", f"/chat/messages/{mid}")
    assert team.cy.call("get", f"/chat/conversations/{cid}/pins").data == []  # deleting unpins
    assert team.ann.call("post", f"/chat/messages/{mid}/pin").status_code == 409


def test_dm_both_may_pin_and_voice_only_in_dm(team, grp):
    dm = team.ann.call("post", "/chat/dm", {"user_id": team.users.bob.id}).data
    audio = upload(team.ann, dm["subject_id"], "audio/mpeg", b"ID3" + b"0" * 20)
    assert audio.status_code == 201, audio.content
    voice = team.ann.call("post", f"/chat/conversations/{dm['id']}/messages", {"file_id": audio.data["id"], "kind": "voice"})
    assert voice.status_code == 201 and voice.data["kind"] == "voice" and voice.data["file"]["content_type"] == "audio/mpeg"
    assert team.bob.call("post", f"/chat/messages/{voice.data['id']}/pin").status_code == 200
    assert team.bob.call("patch", f"/chat/messages/{voice.data['id']}", {"text": "x"}).status_code == 403
    in_group = upload(team.ann, grp["subject_id"], "audio/mpeg", b"ID3" + b"0" * 20)
    refused = team.ann.call("post", f"/chat/conversations/{grp['id']}/messages",
                            {"file_id": in_group.data["id"], "kind": "voice"})
    assert refused.status_code == 422
    plain_audio = team.ann.call("post", f"/chat/conversations/{grp['id']}/messages", {"file_id": in_group.data["id"]})
    assert plain_audio.status_code == 201 and plain_audio.data["kind"] == "file"


def test_files_images_pdf_and_foreign_file_refused(team, grp):
    img = upload(team.ann, grp["subject_id"])
    assert img.status_code == 201
    msg = say(team.ann, grp, "look", file_id=img.data["id"])
    assert msg["kind"] == "file" and msg["file"]["name"] == "f.bin"
    assert upload(team.ann, grp["subject_id"], "text/html", b"<b>").status_code == 422
    other = make_group(team.ann, team.users.bob, name="Other")
    foreign = team.ann.call("post", f"/chat/conversations/{other['id']}/messages", {"file_id": img.data["id"]})
    assert foreign.status_code == 422
    assert team.ann.call("post", f"/chat/conversations/{grp['id']}/messages", {"kind": "file"}).status_code == 422
    assert team.ann.call("post", f"/chat/conversations/{grp['id']}/messages", {"text": "x", "kind": "system"}).status_code == 422
    assert team.dee.call("get", f"/subjects/{grp['subject_id']}/files").status_code == 404


def test_rate_limit_and_archived(team, grp, monkeypatch):
    from chat import messaging

    monkeypatch.setattr(messaging, "RATE_MAX", 3)
    for _ in range(3):
        say(team.ann, grp, "ok")
    assert team.ann.call("post", f"/chat/conversations/{grp['id']}/messages", {"text": "x"}).status_code == 429
    say(team.bob, grp, "other users have their own budget")
    team.ann.call("patch", f"/chat/conversations/{grp['id']}", {"archived": True})
    assert team.bob.call("post", f"/chat/conversations/{grp['id']}/messages", {"text": "x"}).status_code == 409


def test_search_scope(team, grp):
    secret = make_group(team.ann, team.users.dee, name="Hidden")
    say(team.ann, grp, "the Budget is ready")
    say(team.ann, secret, "budget for dee only")
    hits = team.bob.call("get", "/chat/search?q=budget").data
    assert [h["text"] for h in hits] == ["the Budget is ready"]
    both = team.ann.call("get", "/chat/search?q=BUDGET").data
    assert len(both) == 2
    only = team.ann.call("get", f"/chat/search?q=budget&conversation={grp['id']}").data
    assert len(only) == 1
    mid = hits[0]["id"]
    team.ann.call("delete", f"/chat/messages/{mid}")
    assert team.bob.call("get", "/chat/search?q=budget").data == []


def test_search_scans_only_most_recent(team, grp, monkeypatch):
    from chat import search

    monkeypatch.setattr(search, "SCAN_CAP", 2)
    say(team.ann, grp, "needle")
    say(team.ann, grp, "x1")
    say(team.ann, grp, "x2")
    assert team.bob.call("get", "/chat/search?q=needle").data == []


def test_to_task_creates_task_and_system_message(team, grp, make_user, login):
    msg = say(team.ann, grp, "please prepare the report")
    resp = team.bob.call("post", f"/chat/messages/{msg['id']}/to-task",
                         {"owner_ids": [team.users.cy.id]})
    assert resp.status_code == 201, resp.content
    assert resp.data["title"] == "please prepare the report" and resp.data["owner_ids"] == [team.users.cy.id]
    task = team.bob.call("get", f"/tasks/{resp.data['id']}").data
    assert task["description"]["text"] == "please prepare the report"
    last = team.ann.call("get", f"/chat/conversations/{grp['id']}/messages").data[-1]
    assert last["kind"] == "system" and last["data"] == {"event": "task_created", "task_id": resp.data["id"]}
    assert last["reply_to"]["id"] == msg["id"]
    named = team.bob.call("post", f"/chat/messages/{msg['id']}/to-task", {"title": "Report"})
    assert named.data["title"] == "Report"
    plain = login(make_user("plain@corp.test"))
    assert plain.call("post", f"/chat/messages/{msg['id']}/to-task").status_code == 404
    nobody = login(make_user("nogrant@corp.test"))
    team.ann.call("put", f"/chat/conversations/{grp['id']}/members", [
        {"user_id": team.users.ann.id, "role": "admin"}, {"user_id": nobody.user.id, "role": "member"}])
    assert nobody.call("post", f"/chat/messages/{msg['id']}/to-task").status_code == 403
    team.ann.call("delete", f"/chat/messages/{msg['id']}")
    assert team.ann.call("post", f"/chat/messages/{msg['id']}/to-task").status_code == 409


def test_registry_permissions_for_polls_and_comments(team, grp):
    from workspace import registry
    from workspace.models import Subject

    conv = registry.get("chat").resolve(Subject.objects.get(pk=grp["subject_id"]))
    can = registry.get("chat").can
    assert can(team.users.bob, conv, "see") and can(team.users.bob, conv, "comment")
    assert not can(team.users.dee, conv, "see") and not can(team.users.dee, conv, "comment")
    chan = make_group(team.ann, team.users.bob, kind="channel")
    cconv = registry.get("chat").resolve(Subject.objects.get(pk=chan["subject_id"]))
    assert can(team.users.bob, cconv, "see") and not can(team.users.bob, cconv, "comment")
    poll = team.ann.call("post", "/polls", {"target_subject_id": grp["subject_id"], "title": "Lunch?",
                                              "questions": [{"text": "where", "options": ["a", "b"]}]})
    assert poll.status_code == 201, poll.content
    assert team.bob.call("get", f"/polls/{poll.data['id']}").status_code == 200
    assert team.dee.call("get", f"/polls/{poll.data['id']}").status_code == 404
