import json

import pytest

from chat import transfer
from chat.models import Conversation, ConversationMember, PinnedMessage
from workspace.models import Event, EventRecipient

from .conftest import make_group, say


def _project(team, *members):
    body = {"name": "Apollo", "members": [{"user_id": u.id, "role": r} for u, r in members]}
    resp = team.ann.call("post", "/projects", body)
    assert resp.status_code == 201, resp.content
    return resp.data


def test_project_chat_mirrors_members(team):
    u = team.users
    project = _project(team, (u.bob, "member"), (u.cy, "manager"))
    chat = team.ann.call("get", f"/projects/{project['id']}/chat")
    assert chat.status_code == 200 and chat.data["project_id"] == project["id"]
    assert chat.data["name"] == "Apollo" and chat.data["member_count"] == 3
    roles = {m["user"]["id"]: m["role"] for m in chat.data["members"]}
    assert roles == {u.ann.id: "admin", u.bob.id: "member", u.cy.id: "admin"}  # managers are admins
    assert team.bob.call("get", f"/projects/{project['id']}/chat").data["id"] == chat.data["id"]  # one conversation
    assert team.dee.call("get", f"/projects/{project['id']}/chat").status_code == 404
    say(team.bob, chat.data, "hello team")

    team.ann.call("put", f"/projects/{project['id']}/members", [
        {"user_id": u.ann.id, "role": "manager"}, {"user_id": u.bob.id, "role": "member"},
        {"user_id": u.dee.id, "role": "viewer"}])
    after = team.ann.call("get", f"/chat/conversations/{chat.data['id']}").data
    assert {m["user"]["id"] for m in after["members"]} == {u.ann.id, u.bob.id, u.dee.id}
    assert team.dee.call("get", f"/chat/conversations/{chat.data['id']}/messages").status_code == 200
    assert team.cy.call("get", f"/chat/conversations/{chat.data['id']}").status_code == 404  # removed from project
    assert ConversationMember.objects.filter(conversation_id=chat.data["id"], user=u.cy, active=False).exists()
    assert team.bob.call("put", f"/chat/conversations/{chat.data['id']}/members", []).status_code == 403
    assert team.ann.call("post", f"/chat/conversations/{chat.data['id']}/leave").status_code == 422
    assert team.ann.call("put", f"/chat/conversations/{chat.data['id']}/members",
                         [{"user_id": u.ann.id, "role": "admin"}]).status_code == 422


def test_project_chat_follows_bulk_member_changes(team):
    from projects.models import ProjectMember

    u = team.users
    project = _project(team, (u.bob, "member"))
    chat = team.ann.call("get", f"/projects/{project['id']}/chat").data
    ProjectMember.objects.filter(project_id=project["id"], user=u.bob).update(active=False)  # no signal fires
    assert team.bob.call("get", f"/chat/conversations/{chat['id']}").status_code == 404  # lazy sync on access
    assert team.bob.call("post", f"/chat/conversations/{chat['id']}/messages", {"text": "x"}).status_code == 404


def test_customer_chat_mirrors_members(team):
    u = team.users
    cust = team.ann.call("post", "/customers", {"name": "ACME", "members": [{"user_id": u.bob.id, "role": "member"}]})
    assert cust.status_code == 201, cust.content
    chat = team.bob.call("get", f"/customers/{cust.data['id']}/chat")
    assert chat.status_code == 200 and chat.data["customer_id"] == cust.data["id"] and chat.data["member_count"] == 2
    assert team.cy.call("get", f"/customers/{cust.data['id']}/chat").status_code == 404
    team.ann.call("put", f"/customers/{cust.data['id']}/members", [
        {"user_id": u.ann.id, "role": "manager"}, {"user_id": u.cy.id, "role": "member"}])
    assert team.cy.call("get", f"/chat/conversations/{chat.data['id']}").status_code == 200
    assert team.bob.call("get", f"/chat/conversations/{chat.data['id']}").status_code == 404


def test_project_chat_needs_modules(team, brand_dir):
    project = _project(team)
    brand_dir(modules=["projects", "tasks"])
    assert team.ann.call("get", f"/projects/{project['id']}/chat").status_code == 404


@pytest.fixture
def frames(monkeypatch):
    sent: list[tuple[int, dict]] = []
    monkeypatch.setattr("chat.events.push", lambda uid, frame: sent.append((uid, frame)))
    return sent


def test_events_preview_only_for_unmuted_and_never_stored(team, frames, django_capture_on_commit_callbacks):
    u = team.users
    conv = make_group(team.ann, u.bob, u.cy)
    team.cy.call("post", f"/chat/conversations/{conv['id']}/mute", {"muted": True})
    frames.clear()
    with django_capture_on_commit_callbacks(execute=True):
        msg = say(team.ann, conv, "x" * 200)
    got = {uid: f for uid, f in frames if f["kind"] == "chat.message"}
    assert set(got) == {u.ann.id, u.bob.id, u.cy.id}  # events still reach muted members
    assert got[u.bob.id]["data"]["preview"] == "x" * 79 + "…"
    assert "preview" not in got[u.cy.id]["data"]
    data = got[u.bob.id]["data"]
    assert data["conversation_id"] == conv["id"] and data["seq"] == 1 and data["author_id"] == u.ann.id
    assert got[u.bob.id]["stream"] == "w" and got[u.bob.id]["module"] == "chat" and len(json.dumps(data)) < 300
    stored = Event.objects.get(kind="chat.message")
    assert "preview" not in stored.data and "xxxx" not in json.dumps(stored.data)
    assert EventRecipient.objects.filter(event=stored).count() == 3
    frames.clear()
    with django_capture_on_commit_callbacks(execute=True):
        team.bob.call("patch", f"/chat/messages/{msg['id']}", {"text": "y"})
        team.ann.call("post", f"/chat/messages/{msg['id']}/pin")
        team.cy.call("post", f"/chat/conversations/{conv['id']}/read", {"seq": 1})
        team.ann.call("delete", f"/chat/messages/{msg['id']}")
    kinds = {f["kind"] for _, f in frames}
    assert {"chat.message_deleted", "chat.pinned", "chat.read"} <= kinds
    assert "chat.message_edited" not in kinds  # bob is not the author
    with django_capture_on_commit_callbacks(execute=True):
        team.ann.call("put", f"/chat/conversations/{conv['id']}/members", [
            {"user_id": u.ann.id, "role": "admin"}, {"user_id": u.dee.id, "role": "member"}])
    assert Event.objects.filter(kind="chat.member_added").exists()


def test_audit_never_holds_message_text(team):
    from accounts.models import AuditEvent

    conv = make_group(team.ann, team.users.bob)
    say(team.ann, conv, "confidential sentence")
    assert AuditEvent.objects.filter(action="chat_message_sent").exists()
    assert "confidential" not in json.dumps(list(AuditEvent.objects.values_list("data", "target")))


def test_transfer_moves_admin_membership_and_pins(team):
    u = team.users
    conv = make_group(team.ann, u.bob, name="Ops")
    msg = say(team.bob, conv, "pin me")
    team.ann.call("post", f"/chat/messages/{msg['id']}/pin")
    dm = team.ann.call("post", "/chat/dm", {"user_id": u.cy.id}).data
    moved = transfer.transfer(u.ann, u.dee, u.cy)
    assert moved == {"chat": 1, "chat_pins": 1}
    assert team.ann.call("get", f"/chat/conversations/{conv['id']}").status_code == 404
    assert team.dee.call("get", f"/chat/conversations/{conv['id']}").data["my_role"] == "admin"
    assert Conversation.objects.get(pk=conv["id"]).creator_id == u.dee.id
    assert PinnedMessage.objects.get(message_id=msg["id"]).pinned_by_id == u.dee.id
    assert team.ann.call("get", f"/chat/conversations/{dm['id']}").status_code == 200  # dm stays


def test_transfer_hook_is_registered_with_the_workspace_transfer(team, manager, login):
    from workspace import registry

    assert registry.get("chat").transfer is transfer.transfer
    conv = make_group(team.ann, team.users.bob)
    resp = login(manager).call("post", f"/users/{team.users.ann.id}/transfer", {"to_user_id": team.users.dee.id})
    assert resp.status_code == 200 and resp.data["moved"]["chat"] == 1
    assert team.dee.call("get", f"/chat/conversations/{conv['id']}").status_code == 200
