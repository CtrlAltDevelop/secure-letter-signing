import pytest

from chat.models import Conversation, ConversationMember

from .conftest import make_group, say


def test_create_group_and_visibility(team, manager, login):
    u = team.users
    conv = make_group(team.ann, u.bob, description="d")
    assert conv["kind"] == "group" and conv["post_policy"] == "all" and conv["member_count"] == 2
    assert conv["my_role"] == "admin" and conv["can"] == {"post": True, "admin": True, "join": False}
    assert team.bob.call("get", f"/chat/conversations/{conv['id']}").data["my_role"] == "member"
    for outsider in (team.cy, login(manager)):
        assert outsider.call("get", f"/chat/conversations/{conv['id']}").status_code == 404
        assert outsider.call("get", f"/chat/conversations/{conv['id']}/messages").status_code == 404
        assert outsider.call("get", f"/subjects/{conv['subject_id']}/comments").status_code == 404
    assert [c["id"] for c in team.cy.call("get", "/chat/conversations?mine=true").data] == []
    assert [c["id"] for c in team.bob.call("get", "/chat/conversations").data] == [conv["id"]]


def test_channel_defaults_to_admin_posting(team):
    u = team.users
    chan = make_group(team.ann, u.bob, kind="channel")
    assert chan["post_policy"] == "admins"
    resp = team.bob.call("post", f"/chat/conversations/{chan['id']}/messages", {"text": "x"})
    assert resp.status_code == 403
    say(team.ann, chan, "announcement")
    team.ann.call("patch", f"/chat/conversations/{chan['id']}", {"post_policy": "all"})
    say(team.bob, chan, "now ok")


def test_create_group_needs_permission_which_manager_can_revoke(team, make_user, login):
    plain = login(make_user("plain@corp.test"))
    assert plain.call("post", "/chat/conversations", {"kind": "group", "name": "x"}).status_code == 403
    assert plain.call("post", "/chat/dm", {"user_id": team.users.ann.id}).status_code == 200  # DMs are open
    assert team.ann.call("post", "/chat/conversations", {"kind": "dm", "name": "x"}).status_code == 422
    team.users.ann.grants.remove(*team.users.ann.grants.filter(code="chat.create_group"))
    assert team.ann.call("post", "/chat/conversations", {"kind": "group", "name": "x"}).status_code == 403


def test_public_vs_private_and_join(team):
    u = team.users
    pub = make_group(team.ann, kind="group", is_public=True, name="Lunch")
    priv = make_group(team.ann, u.bob, name="Secret")
    found = team.cy.call("get", "/chat/conversations?public=true").data
    assert [c["id"] for c in found] == [pub["id"]] and found[0]["can"]["join"] is True
    assert team.cy.call("get", "/chat/conversations?public=true&q=zzz").data == []
    meta = team.cy.call("get", f"/chat/conversations/{pub['id']}").data
    assert meta["is_member"] is False and meta["members"] is None
    assert team.cy.call("get", f"/chat/conversations/{pub['id']}/messages").status_code == 404  # join first
    assert team.cy.call("get", f"/chat/conversations/{priv['id']}").status_code == 404
    assert team.cy.call("post", f"/chat/conversations/{priv['id']}/join").status_code == 404
    joined = team.cy.call("post", f"/chat/conversations/{pub['id']}/join")
    assert joined.status_code == 200 and joined.data["is_member"] is True
    say(team.cy, pub, "hi all")
    assert team.cy.call("post", f"/chat/conversations/{pub['id']}/leave").status_code == 204
    assert team.cy.call("get", f"/chat/conversations/{pub['id']}/messages").status_code == 404


def test_dm_unique_per_pair_and_lazy(team):
    u = team.users
    first = team.ann.call("post", "/chat/dm", {"user_id": u.bob.id}).data
    again = team.bob.call("post", "/chat/dm", {"user_id": u.ann.id}).data
    assert first["id"] == again["id"] and first["kind"] == "dm" and first["last_seq"] == 0
    assert first["name"] == u.bob.full_name and first["other_user"]["id"] == u.bob.id
    assert Conversation.objects.filter(kind="dm").count() == 1
    assert team.ann.call("post", "/chat/dm", {"user_id": u.ann.id}).status_code == 422
    assert team.ann.call("post", "/chat/dm", {"user_id": 99999}).status_code == 422
    assert team.cy.call("get", f"/chat/conversations/{first['id']}").status_code == 404
    assert team.ann.call("post", f"/chat/conversations/{first['id']}/leave").status_code == 422
    assert team.ann.call("patch", f"/chat/conversations/{first['id']}", {"name": "x"}).status_code == 403


def test_member_roles(team):
    u = team.users
    conv = make_group(team.ann, u.bob)
    cid = conv["id"]
    assert team.bob.call("patch", f"/chat/conversations/{cid}", {"name": "Hacked"}).status_code == 403
    roster = [{"user_id": u.ann.id, "role": "admin"}, {"user_id": u.bob.id, "role": "member"},
              {"user_id": u.cy.id, "role": "member"}]
    assert team.bob.call("put", f"/chat/conversations/{cid}/members", roster).status_code == 403
    done = team.ann.call("put", f"/chat/conversations/{cid}/members", roster)
    assert done.status_code == 200 and done.data["member_count"] == 3
    assert team.ann.call("put", f"/chat/conversations/{cid}/members",
                         [{"user_id": u.bob.id, "role": "member"}]).status_code == 422  # no admin
    team.ann.call("put", f"/chat/conversations/{cid}/members", [{"user_id": u.ann.id, "role": "admin"}])
    assert team.bob.call("get", f"/chat/conversations/{cid}").status_code == 404  # deactivated, never deleted
    assert ConversationMember.objects.filter(conversation_id=cid, user=u.bob, active=False).exists()


def test_last_admin_leaving_promotes_oldest_member(team):
    u = team.users
    conv = make_group(team.ann, u.bob, u.cy)
    team.ann.call("post", f"/chat/conversations/{conv['id']}/leave")
    assert team.bob.call("get", f"/chat/conversations/{conv['id']}").data["my_role"] == "admin"


def test_mute_and_pin_conversation_are_per_user(team):
    u = team.users
    a, b = make_group(team.ann, u.bob, name="A"), make_group(team.ann, u.bob, name="B")
    say(team.ann, b, "later")
    assert team.bob.call("post", f"/chat/conversations/{a['id']}/pin", {"pinned": True}).data["pinned"] is True
    assert team.bob.call("post", f"/chat/conversations/{a['id']}/mute", {"muted": True}).data["muted"] is True
    listing = team.bob.call("get", "/chat/conversations?mine=true").data
    assert [c["name"] for c in listing] == ["A", "B"]  # pinned first
    assert team.ann.call("get", f"/chat/conversations/{a['id']}").data["pinned"] is False
    assert [c["name"] for c in team.bob.call("get", "/chat/conversations?q=b&kind=group").data] == ["B"]


def test_module_off_is_404(team, brand_dir):
    brand_dir(modules=["letters"])
    assert team.ann.call("get", "/chat/conversations").status_code == 404
    assert team.ann.call("post", "/chat/dm", {"user_id": team.users.bob.id}).status_code == 404
    assert team.ann.call("get", "/chat/unread").status_code == 404
    assert team.ann.call("get", "/chat/search?q=x").status_code == 404


@pytest.mark.parametrize("table", ["chat_conversation", "chat_conversationmember", "chat_message",
                                   "chat_pinnedmessage", "chat_messageread"])
def test_db_refuses_delete(team, table):
    from django.db import connection, transaction
    from django.db.utils import DatabaseError

    u = team.users
    conv = make_group(team.ann, u.bob)
    msg = say(team.bob, conv, "x")
    team.ann.call("post", f"/chat/messages/{msg['id']}/pin")
    team.ann.call("post", f"/chat/conversations/{conv['id']}/read", {"seq": 1})
    with pytest.raises(DatabaseError), transaction.atomic(), connection.cursor() as cur:
        cur.execute(f"DELETE FROM {table}")
