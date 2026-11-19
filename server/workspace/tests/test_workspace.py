import uuid
from pathlib import Path

import pytest
from asgiref.sync import async_to_sync, sync_to_async
from django.db import connection, transaction

from accounts.admin import import_users_from_csv
from accounts.models import InviteCode, Permission, User
from accounts.tests.conftest import PASSWORD
from core import dbguards, filestore
from workspace import events
from workspace.models import (ChangeHistory, Comment, Event, EventRecipient, File, Label, Reminder, SeenBy, Subject,
                              SubjectLabel)
from workspace.tests.conftest import connect


@pytest.fixture
def people(make_user, login, manager):
    return type("P", (), {
        "boss": login(manager), "manager": manager,
        "ann": (u1 := make_user("ann@corp.test")), "ann_d": login(u1),
        "bob": (u2 := make_user("bob@corp.test")), "bob_d": login(u2),
        "cy": (u3 := make_user("cy@corp.test")), "cy_d": login(u3),
    })


# --- modules ---------------------------------------------------------------------------------------------------


def test_me_modules_default_is_all_enabled(people):
    data = people.ann_d.call("get", "/me/modules").data
    assert data == {"plan": "advanced", "modules": [{"code": c, "enabled": True} for c in ("letters", "tasks", "projects", "meetings", "notes", "polls", "crm", "finance", "sales", "chat", "gantt")]}


def test_me_modules_honours_brand_list_and_registered_modules(people, dummy, brand_dir):
    brand_dir(modules=["letters", "dummy"])
    mods = {m["code"]: m["enabled"] for m in people.ann_d.call("get", "/me/modules").data["modules"]}
    assert mods == {"letters": True, "tasks": False, "projects": False, "meetings": False,
                    "notes": False, "polls": False, "crm": False, "finance": False, "sales": False, "chat": False, "gantt": False, "dummy": True}


def test_me_modules_needs_login(api, db):
    assert api.call("get", "/me/modules").status_code == 401


def test_bad_modules_value_in_brand_is_an_error(brand_dir):
    from core.brand import load_brand

    brand_dir(modules="letters")
    with pytest.raises(RuntimeError, match="modules"):
        load_brand()


def test_disabled_module_is_404_through_require_module(people, dummy, brand_dir):
    subject = dummy.add(edit=[people.ann])
    path = f"/subjects/{subject.id}/labels"
    assert people.ann_d.call("put", path, {"label_ids": []}).status_code == 200
    brand_dir(modules=["letters"])
    assert people.ann_d.call("put", path, {"label_ids": []}).status_code == 404


def test_require_module_raises_404_when_off(brand_dir):
    from ninja.errors import HttpError

    from workspace.registry import require_module

    brand_dir(modules=["letters"])
    require_module("letters")
    with pytest.raises(HttpError) as err:
        require_module("tasks")
    assert err.value.status_code == 404


# --- labels ----------------------------------------------------------------------------------------------------


def test_org_label_needs_the_manager_and_duplicates_conflict(people):
    body = {"name": "Urgent", "color": 2, "scope": "org"}
    assert people.ann_d.call("post", "/labels", body).status_code == 403
    made = people.boss.call("post", "/labels", body)
    assert made.status_code == 201 and made.data["scope"] == "org" and made.data["color"] == 2
    assert people.boss.call("post", "/labels", body).status_code == 409
    assert people.ann_d.call("post", "/labels", {**body, "scope": "personal"}).status_code == 201  # own namespace
    assert people.ann_d.call("post", "/labels", {**body, "scope": "personal"}).status_code == 409


def test_personal_labels_are_private_and_listed_with_org_ones(people):
    org = people.boss.call("post", "/labels", {"name": "Org", "color": 1, "scope": "org"}).data
    mine = people.ann_d.call("post", "/labels", {"name": "Mine", "color": 3, "scope": "personal"}).data
    ann = people.ann_d.call("get", "/labels").data
    assert {x["id"] for x in ann} == {org["id"], mine["id"]}
    assert {x["id"] for x in people.bob_d.call("get", "/labels").data} == {org["id"]}
    assert people.bob_d.call("patch", f"/labels/{mine['id']}", {"name": "x"}).status_code == 404


def test_update_label_permissions_and_deactivate(people):
    org = people.boss.call("post", "/labels", {"name": "Org", "color": 1, "scope": "org"}).data
    mine = people.ann_d.call("post", "/labels", {"name": "Mine", "color": 3, "scope": "personal"}).data
    assert people.ann_d.call("patch", f"/labels/{org['id']}", {"name": "z"}).status_code == 403
    renamed = people.boss.call("patch", f"/labels/{org['id']}", {"name": "Org2", "color": 5})
    assert renamed.data["name"] == "Org2" and renamed.data["color"] == 5
    assert people.ann_d.call("patch", f"/labels/{mine['id']}", {"name": "Org2"}).status_code == 200  # own scope
    assert people.boss.call("patch", f"/labels/{org['id']}", {"name": "Org2"}).status_code == 200  # unchanged name
    other = people.boss.call("post", "/labels", {"name": "Other", "color": 0, "scope": "org"}).data
    assert people.boss.call("patch", f"/labels/{other['id']}", {"name": "Org2"}).status_code == 409
    assert people.ann_d.call("patch", f"/labels/{mine['id']}", {"active": False}).data["active"] is False
    assert mine["id"] not in {x["id"] for x in people.ann_d.call("get", "/labels").data}
    assert mine["id"] in {x["id"] for x in people.ann_d.call("get", "/labels?include_inactive=true").data}
    assert people.ann_d.call("patch", "/labels/99999", {"name": "n"}).status_code == 404


def test_label_input_is_validated(people):
    for bad in ({"name": "", "color": 0, "scope": "org"}, {"name": "x", "color": 99, "scope": "personal"},
                {"name": "x", "color": 0, "scope": "team"}):
        assert people.boss.call("post", "/labels", bad).status_code == 422


# --- subject labels through registry.can -----------------------------------------------------------------------


def test_subject_labels_go_through_registry_can(people, dummy):
    subject = dummy.add(see=[people.bob], edit=[people.ann])
    org = people.boss.call("post", "/labels", {"name": "Org", "color": 1, "scope": "org"}).data["id"]
    mine = people.ann_d.call("post", "/labels", {"name": "Mine", "color": 1, "scope": "personal"}).data["id"]
    path = f"/subjects/{subject.id}/labels"
    done = people.ann_d.call("put", path, {"label_ids": [org, mine, mine]})
    assert done.status_code == 200 and done.data == {"label_ids": sorted([org, mine])}
    assert people.bob_d.call("put", path, {"label_ids": [org]}).status_code == 403  # sees, may not label
    assert people.cy_d.call("put", path, {"label_ids": [org]}).status_code == 404  # invisible
    assert people.ann_d.call("put", f"/subjects/{uuid.uuid4()}/labels", {"label_ids": []}).status_code == 404
    orphan = Subject.objects.create(module="nowhere", kind="x")
    assert people.ann_d.call("put", f"/subjects/{orphan.id}/labels", {"label_ids": []}).status_code == 404


def test_subject_labels_replace_and_keep_other_peoples_personal_labels(people, dummy):
    subject = dummy.add(edit=[people.ann, people.bob])
    org = people.boss.call("post", "/labels", {"name": "Org", "color": 1, "scope": "org"}).data["id"]
    org2 = people.boss.call("post", "/labels", {"name": "Org2", "color": 1, "scope": "org"}).data["id"]
    bobs = people.bob_d.call("post", "/labels", {"name": "B", "color": 1, "scope": "personal"}).data["id"]
    anns = people.ann_d.call("post", "/labels", {"name": "A", "color": 1, "scope": "personal"}).data["id"]
    path = f"/subjects/{subject.id}/labels"
    people.bob_d.call("put", path, {"label_ids": [bobs, org]})
    out = people.ann_d.call("put", path, {"label_ids": [anns, org2]}).data
    assert out["label_ids"] == sorted([anns, org2])  # org replaced, bob's personal one invisible and untouched
    assert people.bob_d.call("put", path, {"label_ids": [bobs]}).data["label_ids"] == [bobs]
    rows = {r.label_id: r.active for r in SubjectLabel.objects.filter(subject=subject)}
    assert rows == {bobs: True, org: False, anns: True, org2: False}
    assert people.bob_d.call("put", path, {"label_ids": [org]}).data["label_ids"] == [org]  # reactivates the old row
    assert SubjectLabel.objects.filter(subject=subject, label_id=org).count() == 1


def test_subject_labels_reject_foreign_or_inactive_labels(people, dummy):
    subject = dummy.add(edit=[people.ann])
    path = f"/subjects/{subject.id}/labels"
    bobs = people.bob_d.call("post", "/labels", {"name": "B", "color": 1, "scope": "personal"}).data["id"]
    assert people.ann_d.call("put", path, {"label_ids": [bobs]}).status_code == 422
    gone = people.boss.call("post", "/labels", {"name": "Gone", "color": 1, "scope": "org"}).data["id"]
    people.boss.call("patch", f"/labels/{gone}", {"active": False})
    assert people.ann_d.call("put", path, {"label_ids": [gone]}).status_code == 422
    assert people.ann_d.call("put", path, {"label_ids": [123456]}).status_code == 422


# --- events ----------------------------------------------------------------------------------------------------


def test_emit_writes_recipients_and_skips_inactive_users(people, dummy, django_capture_on_commit_callbacks):
    subject = dummy.add(edit=[people.ann])
    people.cy.is_active = False
    people.cy.save()
    with django_capture_on_commit_callbacks(execute=True):
        ev = events.emit("dummy", "thing.updated", subject, "T" * 400, people.ann,
                         [people.ann.id, people.bob.id, people.bob.id, people.cy.id], note="n")
    assert set(ev.recipients.values_list("user_id", flat=True)) == {people.ann.id, people.bob.id}
    assert len(ev.title) == 300 and ev.data == {"note": "n"}


def test_events_w_replays_by_cursor_and_only_my_events(people, dummy):
    subject = dummy.add(edit=[people.ann])
    e1 = events.emit("dummy", "a", subject, "one", people.ann, [people.ann.id, people.bob.id])
    e2 = events.emit("dummy", "b", None, "two", None, [people.bob.id])
    e3 = events.emit("dummy", "c", subject, "three", people.ann, [people.ann.id])
    bob = people.bob_d.call("get", "/events/w?after=0&limit=500").data
    assert [f["event_id"] for f in bob] == [e1.id, e2.id]
    assert bob[0] == {"type": "ws", "stream": "w", "event_id": e1.id, "module": "dummy", "kind": "a",
                      "subject_id": str(subject.id), "title": "one", "actor_id": people.ann.id, "data": {},
                      "at": bob[0]["at"]}
    assert bob[1]["subject_id"] is None and bob[1]["actor_id"] is None
    assert [f["event_id"] for f in people.bob_d.call("get", f"/events/w?after={e1.id}").data] == [e2.id]
    assert [f["event_id"] for f in people.ann_d.call("get", "/events/w").data] == [e1.id, e3.id]
    assert [f["event_id"] for f in people.ann_d.call("get", "/events/w?limit=1").data] == [e1.id]
    assert people.cy_d.call("get", "/events/w").data == []


def test_workspace_frames_reach_only_recipients_and_replay_by_after_w(people, dummy, django_capture_on_commit_callbacks):
    subject = dummy.add(edit=[people.ann])

    def emit_now():
        with django_capture_on_commit_callbacks(execute=True):
            return events.emit("dummy", "thing.updated", subject, "Hello", people.ann, [people.ann.id, people.bob.id])

    async def scenario():
        ann, bob, cy = (connect(d.token) for d in (people.ann_d, people.bob_d, people.cy_d))
        for ws in (ann, bob, cy):
            assert (await ws.connect())[0]
        ev = await sync_to_async(emit_now, thread_sensitive=True)()
        for ws in (ann, bob):
            frame = await ws.receive_json_from(timeout=2)
            assert frame["type"] == "ws" and frame["stream"] == "w" and frame["event_id"] == ev.id
            assert frame["module"] == "dummy" and frame["title"] == "Hello"
        assert await cy.receive_nothing(timeout=0.2)
        await bob.disconnect()
        again = connect(people.bob_d.token)
        await again.connect()
        await again.send_json_to({"after_w": 0})
        assert (await again.receive_json_from(timeout=2))["event_id"] == ev.id
        await again.send_json_to({"after_w": ev.id})
        assert await again.receive_nothing(timeout=0.2)
        await cy.send_json_to({"after_w": 0, "after": 0})
        assert await cy.receive_nothing(timeout=0.2)
        for ws in (ann, again, cy):
            await ws.disconnect()

    async_to_sync(scenario)()


# --- database guards -------------------------------------------------------------------------------------------


@pytest.fixture
def rows(people, dummy):
    subject = dummy.add(edit=[people.ann])
    ev = Event.objects.create(module="dummy", kind="k", subject=subject)
    blob = File(subject=subject, uploaded_by=people.ann, name="a", content_type="text/plain", size=1, sha256_plain="0")
    filestore.save_encrypted(blob.blob, b"x")
    blob.save()
    comment = Comment.objects.create(subject=subject, author=people.ann)
    return {
        Subject: subject, Label: Label.objects.create(scope="org", name="L"),
        SubjectLabel: SubjectLabel.objects.create(subject=subject, label=Label.objects.get(name="L")),
        File: blob, Comment: comment, ChangeHistory: ChangeHistory.objects.create(subject=subject, field="f"),
        SeenBy: SeenBy.objects.create(subject=subject, user=people.ann), Event: ev,
        EventRecipient: EventRecipient.objects.create(event=ev, user=people.ann),
        Reminder: Reminder.objects.create(subject=subject, user=people.ann, created_by=people.ann, next_at=ev.at),
    }


def test_database_refuses_delete_on_every_workspace_table(rows):
    for model, row in rows.items():
        with pytest.raises(Exception, match="not allowed"), transaction.atomic():
            with connection.cursor() as cur:
                cur.execute(f"DELETE FROM {model._meta.db_table}")
        assert model.objects.filter(pk=row.pk).exists()


def test_database_refuses_update_on_event_recipient_and_history_only(rows, people):
    for model in (Event, EventRecipient, ChangeHistory):
        with pytest.raises(Exception, match="not allowed"), transaction.atomic():
            with connection.cursor() as cur:
                cur.execute(f"UPDATE {model._meta.db_table} SET id = id")
    Label.objects.filter(pk=rows[Label].pk).update(name="renamed")
    Comment.objects.filter(pk=rows[Comment].pk).update(active=False)
    Reminder.objects.filter(pk=rows[Reminder].pk).update(active=False)
    SeenBy.objects.filter(pk=rows[SeenBy].pk).update(last_at=rows[Event].at)


def test_dbguards_rejects_unknown_vendors():
    with pytest.raises(NotImplementedError):
        dbguards.statements("mysql", "DELETE", "t")
    create, drop = dbguards.statements("postgresql", "UPDATE", "t")
    assert "no_update_t_fn" in create[0] and "DROP TRIGGER" in drop[0]


# --- file store ------------------------------------------------------------------------------------------------


def test_filestore_round_trips_and_keeps_only_ciphertext_on_disk(rows, settings, tmp_path):
    settings.MEDIA_ROOT = tmp_path
    plain = b"%PDF-1.7 secret payroll"
    blob = rows[File]
    filestore.save_encrypted(blob.blob, plain)
    blob.save()
    raw = Path(blob.blob.path).read_bytes()
    assert plain not in raw and raw != plain and raw.startswith(b"gAAAA")
    assert filestore.read_decrypted(File.objects.get(pk=blob.pk).blob) == plain


def test_filestore_wrong_key_raises_decrypt_error(rows, settings, tmp_path):
    settings.MEDIA_ROOT = tmp_path
    blob = rows[File]
    filestore.save_encrypted(blob.blob, b"data")
    settings.DATA_KEY = "another-data-key-entirely"
    with pytest.raises(filestore.DecryptError):
        filestore.read_decrypted(blob.blob)


# --- permissions -----------------------------------------------------------------------------------------------


def test_permissions_are_seeded(db):
    assert set(Permission.objects.filter(code__in=["task.create", "project.create"]).values_list("code", flat=True)) == {
        "task.create", "project.create"}


def test_new_users_get_the_default_grants(api, manager, company, db):
    company.signup_invite_enabled = True
    company.save()
    invite = InviteCode.objects.create(created_by=manager, max_uses=1)
    assert api.call("post", "/auth/signup", {"email": "n@x.test", "password": PASSWORD,
                                             "invite_code": invite.code}).status_code == 201
    expected = ["chat.create_group", "customer.create", "project.create", "task.create", "user"]
    assert api.login("n@x.test")["user"]["permissions"] == expected
    report = import_users_from_csv("email,full_name\nimp@corp.test,Imp\n")
    assert report["created"] == ["imp@corp.test"]
    assert sorted(User.objects.get(email="imp@corp.test").grants.values_list("code", flat=True)) == expected
