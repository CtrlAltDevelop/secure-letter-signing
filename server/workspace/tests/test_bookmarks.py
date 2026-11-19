import pytest

from letters.models import Letter
from workspace import registry
from workspace.models import Bookmark, Pin


@pytest.fixture(autouse=True)
def _modules(brand_dir):
    brand_dir()


@pytest.fixture
def crew(make_user, login, manager):
    crew = type("Crew", (), {})()
    crew.manager, crew.boss = manager, login(manager)
    grants = ("task.create", "project.create", "customer.create", "chat.create_group")
    for name in ("ann", "bob", "out"):
        user = make_user(f"{name}@corp.test", grants=grants)
        setattr(crew, name, user)
        setattr(crew, f"{name}_d", login(user))
    return crew


def put(who, module, target, **extra):
    return who.call("put", "/bookmarks", {"module": module, "id": target, **extra})


def test_bookmark_a_task_by_subject_or_object_id_is_one_row(crew):
    task = crew.ann_d.call("post", "/tasks", {"title": "Plan"}).data
    first = put(crew.ann_d, "tasks", task["id"], note="check later")
    assert first.status_code == 200, first.content
    assert first.data["subject_id"] == task["subject_id"] and first.data["object_id"] == task["id"]
    assert (first.data["title"], first.data["note"], first.data["module"], first.data["kind"]) == (
        "Plan", "check later", "tasks", "task")
    again = put(crew.ann_d, "tasks", task["subject_id"])  # same target through the subject id
    assert again.data["id"] == first.data["id"] and again.data["note"] == "check later"
    assert Bookmark.objects.count() == 1
    assert put(crew.ann_d, "tasks", task["id"], note="").data["note"] == ""
    assert [b["id"] for b in crew.ann_d.call("get", "/bookmarks").data] == [first.data["id"]]
    assert crew.ann_d.call("get", "/bookmarks?module=letters").data == []


def test_note_is_encrypted_at_rest(crew):
    task = crew.ann_d.call("post", "/tasks", {"title": "Plan"}).data
    put(crew.ann_d, "tasks", task["id"], note="very private words")
    assert "very private" not in str(Bookmark.objects.get().note)


def test_cannot_bookmark_what_you_cannot_see(crew):
    task = crew.ann_d.call("post", "/tasks", {"title": "Plan"}).data
    assert put(crew.bob_d, "tasks", task["id"]).status_code == 404
    assert put(crew.boss, "tasks", task["subject_id"]).status_code == 404
    assert put(crew.ann_d, "tasks", "not-a-uuid").status_code == 404
    assert put(crew.ann_d, "nosuchmodule", task["id"]).status_code == 404
    assert Bookmark.objects.count() == 0


def test_bookmark_disappears_when_access_is_lost_and_when_module_is_off(crew, brand_dir):
    task = crew.ann_d.call("post", "/tasks", {"title": "Shared", "owner_ids": [crew.bob.id]}).data
    bid = put(crew.bob_d, "tasks", task["id"]).data["id"]
    crew.ann_d.call("put", f"/tasks/{task['id']}/people", {"owner_ids": [crew.ann.id]})
    assert crew.bob_d.call("get", "/bookmarks").data == []
    assert Bookmark.objects.get(pk=bid).active is True  # hidden, not removed
    brand_dir(modules=["letters"])
    assert crew.ann_d.call("get", "/bookmarks").data == []


def test_delete_deactivates_and_put_reactivates(crew):
    task = crew.ann_d.call("post", "/tasks", {"title": "Plan"}).data
    bid = put(crew.ann_d, "tasks", task["id"]).data["id"]
    assert crew.bob_d.call("delete", f"/bookmarks/{bid}").status_code == 404
    assert crew.ann_d.call("delete", f"/bookmarks/{bid}").status_code == 204
    assert crew.ann_d.call("delete", f"/bookmarks/{bid}").status_code == 404
    assert crew.ann_d.call("get", "/bookmarks").data == []
    assert Bookmark.objects.get(pk=bid).active is False
    assert put(crew.ann_d, "tasks", task["id"]).data["id"] == bid
    assert len(crew.ann_d.call("get", "/bookmarks").data) == 1


def test_letter_bookmark(crew):
    letter = Letter.objects.create(no=7, title="Contract", creator=crew.ann, status="draft", visibility="private",
                                   publish_mode="now", order="parallel", body={})
    from workspace.models import Subject

    letter.subject = Subject.objects.create(module="letters", kind="letter")
    letter.save()
    row = put(crew.ann_d, "letters", str(letter.id))
    assert row.status_code == 200 and row.data["title"] == "Contract" and row.data["object_id"] == str(letter.id)
    assert put(crew.bob_d, "letters", str(letter.id)).status_code == 404


def test_chat_message_bookmark_uses_the_verifying_hook(crew):
    conv = crew.ann_d.call("post", "/chat/conversations", {"kind": "group", "name": "Room",
                                                           "member_ids": [crew.bob.id]}).data
    msg = crew.ann_d.call("post", f"/chat/conversations/{conv['id']}/messages", {"text": "secret words"}).data
    row = put(crew.bob_d, "chat", str(msg["id"]), note="n")
    assert row.status_code == 200, row.content
    assert (row.data["module"], row.data["kind"], row.data["subject_id"], row.data["title"]) == (
        "chat", "message", None, "Room")
    assert "secret words" not in str(row.data) and "secret words" not in str(Bookmark.objects.get().title)
    assert put(crew.out_d, "chat", str(msg["id"])).status_code == 404  # not a member
    assert put(crew.bob_d, "chat", "999999").status_code == 404
    assert put(crew.bob_d, "chat", "abc").status_code == 404
    assert [b["target_id"] for b in crew.bob_d.call("get", "/bookmarks?module=chat").data] == [str(msg["id"])]


def test_non_subject_module_without_a_hook_is_refused(crew):
    registry.register(registry.ModuleSpec("loose", None, lambda s: None, lambda u, o, a: True))
    try:
        assert put(crew.ann_d, "loose", "1").status_code == 404
    finally:
        registry.unregister("loose")


# --- pins -----------------------------------------------------------------------------------------------------

def test_pins_for_projects_files_and_conversations(crew):
    project = crew.ann_d.call("post", "/projects", {"name": "Site", "members": []}).data
    customer = crew.ann_d.call("post", "/customers", {"name": "ACME"}).data
    conv = crew.ann_d.call("post", "/chat/conversations", {"kind": "group", "name": "Room", "member_ids": []}).data
    for subject in (project["subject_id"], customer["subject_id"], conv["subject_id"]):
        assert crew.ann_d.call("put", "/pins", {"subject_id": subject}).status_code == 200
    pins = crew.ann_d.call("get", "/pins").data
    assert pins == [
        {"subject_id": project["subject_id"], "module": "projects", "kind": pins[0]["kind"], "title": "Site"},
        {"subject_id": customer["subject_id"], "module": "crm", "kind": pins[1]["kind"], "title": "ACME"},
        {"subject_id": conv["subject_id"], "module": "chat", "kind": pins[2]["kind"], "title": "Room"}]
    again = crew.ann_d.call("put", "/pins", {"subject_id": project["subject_id"]})
    assert len(again.data) == 3 and Pin.objects.count() == 3  # idempotent
    assert crew.bob_d.call("get", "/pins").data == []


def test_pin_validation_and_removal(crew):
    project = crew.ann_d.call("post", "/projects", {"name": "Site", "members": []}).data
    task = crew.ann_d.call("post", "/tasks", {"title": "T"}).data
    assert crew.bob_d.call("put", "/pins", {"subject_id": project["subject_id"]}).status_code == 404
    assert crew.boss.call("put", "/pins", {"subject_id": project["subject_id"]}).status_code == 404
    assert crew.ann_d.call("put", "/pins", {"subject_id": task["subject_id"]}).status_code == 422  # tasks: bookmarks
    assert crew.ann_d.call("put", "/pins", {"subject_id": "00000000-0000-0000-0000-000000000000"}).status_code == 422
    crew.ann_d.call("put", "/pins", {"subject_id": project["subject_id"]})
    assert crew.bob_d.call("delete", f"/pins/{project['subject_id']}").status_code == 404
    assert crew.ann_d.call("delete", f"/pins/{project['subject_id']}").status_code == 204
    assert crew.ann_d.call("delete", f"/pins/{project['subject_id']}").status_code == 404
    assert crew.ann_d.call("get", "/pins").data == []
    assert Pin.objects.get().active is False
    again = crew.ann_d.call("put", "/pins", {"subject_id": project["subject_id"]})
    assert [p["subject_id"] for p in again.data] == [project["subject_id"]]


def test_pin_is_hidden_after_access_is_lost(crew):
    project = crew.ann_d.call("post", "/projects", {"name": "Site", "members": [
        {"user_id": crew.bob.id, "role": "member"}]}).data
    assert crew.bob_d.call("put", "/pins", {"subject_id": project["subject_id"]}).status_code == 200
    crew.ann_d.call("put", f"/projects/{project['id']}/members", [{"user_id": crew.ann.id, "role": "manager"}])
    assert crew.bob_d.call("get", "/pins").data == []
