"""Phase 4: comments, files, history, seen-by on any subject (tasks module for the real rules, dummy for generic)."""
import hashlib

import pytest
from django.core.files.uploadedfile import SimpleUploadedFile
from django.db import connection, transaction

from tasks.tests.conftest import make_task, team  # noqa: F401
from workspace.models import Comment, Event, EventRecipient, File, SeenBy
from workspace.textbox import open_text

PDF = b"%PDF-1.4 top secret payroll"


@pytest.fixture
def task(make_task, team):  # noqa: F811
    return make_task(follower_ids=[team.fay.id])


def comments(task):
    return f"/subjects/{task['subject_id']}/comments"


def upload(who, task, data=PDF, name="payroll.pdf", ctype="application/pdf"):
    return who.api.client.post(
        f"/api/subjects/{task['subject_id']}/files",
        {"content_type": ctype, "name": name, "file": SimpleUploadedFile("ignored.pdf", data)},
        HTTP_AUTHORIZATION=f"Bearer {who.token}")


def test_comment_permissions_follow_the_module(team, task):
    body = {"body": {"text": "hello"}}
    assert team.out_d.call("get", comments(task)).status_code == 404
    assert team.out_d.call("post", comments(task), body).status_code == 404
    assert team.boss.call("post", comments(task), body).status_code == 404
    for who in (team.cat_d, team.olga_d, team.fay_d):
        assert who.call("post", comments(task), body).status_code == 201
    assert len(team.fay_d.call("get", comments(task)).data) == 3
    assert team.cat_d.call("get", f"/tasks/{task['id']}").data["comment_count"] == 3


def test_unknown_subject_is_404(team):
    assert team.cat_d.call("get", "/subjects/6f1f9f7e-9d19-4d4b-8f44-0d6a55a6f0a1/comments").status_code == 404


def test_comment_body_is_encrypted_and_replies_are_one_level(team, task):
    top = team.cat_d.call("post", comments(task), {"body": {"text": "confidential words"}}).data
    row = Comment.objects.get(pk=top["id"])
    assert row.body["v"] == 3 and "confidential" not in str(row.body)
    reply = team.olga_d.call("post", comments(task), {"body": {"text": "ok"}, "parent_id": top["id"]})
    assert reply.status_code == 201 and reply.data["parent_id"] == top["id"]
    deeper = team.fay_d.call("post", comments(task), {"body": {"text": "no"}, "parent_id": reply.data["id"]})
    assert deeper.status_code == 422
    assert team.fay_d.call("post", comments(task), {"body": {"text": "no"}, "parent_id": 99999}).status_code == 422
    assert team.fay_d.call("post", comments(task), {"body": {"text": "  "}}).status_code == 422
    assert team.fay_d.call("post", comments(task), {"body": {"text": "x"}, "progress": 5}).status_code == 422
    thread = team.fay_d.call("get", comments(task)).data
    assert len(thread) == 1 and [r["body"]["text"] for r in thread[0]["replies"]] == ["ok"]


def test_reply_parent_must_belong_to_the_same_subject(team, task, make_task):  # noqa: F811
    other = make_task()
    foreign = team.cat_d.call("post", comments(other), {"body": {"text": "elsewhere"}}).data
    resp = team.cat_d.call("post", comments(task), {"body": {"text": "x"}, "parent_id": foreign["id"]})
    assert resp.status_code == 422


def test_edit_creates_a_replacing_row_and_keeps_replies(team, task):
    top = team.cat_d.call("post", comments(task), {"body": {"text": "v1"}}).data
    team.olga_d.call("post", comments(task), {"body": {"text": "reply"}, "parent_id": top["id"]})
    assert team.olga_d.call("patch", f"/comments/{top['id']}", {"body": {"text": "hijack"}}).status_code == 403
    assert team.out_d.call("patch", f"/comments/{top['id']}", {"body": {"text": "x"}}).status_code == 404
    edited = team.cat_d.call("patch", f"/comments/{top['id']}", {"body": {"text": "v2"}}).data
    assert edited["edited"] is True and edited["body"]["text"] == "v2" and edited["id"] != top["id"]
    old = Comment.objects.get(pk=top["id"])
    assert old.active is False and open_text(old.body) == "v1"
    assert Comment.objects.get(pk=edited["id"]).replaces_id == old.id
    thread = team.fay_d.call("get", comments(task)).data
    assert [c["body"]["text"] for c in thread] == ["v2"] and len(thread[0]["replies"]) == 1
    assert team.cat_d.call("patch", f"/comments/{top['id']}", {"body": {"text": "again"}}).status_code == 404


def test_deactivate_by_author_or_manager_of_the_object(team, task):
    mine = team.fay_d.call("post", comments(task), {"body": {"text": "mine"}}).data
    other = team.fay_d.call("post", comments(task), {"body": {"text": "other"}}).data
    assert team.olga_d.call("delete", f"/comments/{mine['id']}").status_code == 403  # owner is not a moderator
    assert team.fay_d.call("delete", f"/comments/{mine['id']}").status_code == 204
    assert team.cat_d.call("delete", f"/comments/{other['id']}").status_code == 204  # creator moderates
    assert team.cat_d.call("get", comments(task)).data == []
    assert Comment.objects.filter(pk__in=[mine["id"], other["id"]], active=False).count() == 2
    assert team.fay_d.call("delete", f"/comments/{mine['id']}").status_code == 404


def test_comment_event_goes_to_audience_without_the_author(team, task):
    team.fay_d.call("post", comments(task), {"body": {"text": "ping"}})
    ev = Event.objects.get(kind="comment.created")
    got = set(EventRecipient.objects.filter(event=ev).values_list("user_id", flat=True))
    assert got == {team.cat.id, team.olga.id} and ev.module == "tasks" and ev.actor_id == team.fay.id
    assert "ping" not in str(ev.data)


def test_files_round_trip_encrypted_on_disk(team, task):
    resp = upload(team.fay_d, task)
    assert resp.status_code == 201, resp.content
    data = resp.json()
    assert data["name"] == "payroll.pdf" and data["size"] == len(PDF)
    assert data["sha256"] == hashlib.sha256(PDF).hexdigest() and data["uploaded_by"]["id"] == team.fay.id
    row = File.objects.get(pk=data["id"])
    with row.blob.open("rb") as handle:
        assert PDF not in handle.read()
    got = team.olga_d.api.client.get(f"/api/files/{data['id']}", HTTP_AUTHORIZATION=f"Bearer {team.olga_d.token}")
    assert got.status_code == 200 and got.content == PDF and got["Content-Type"] == "application/pdf"
    assert "attachment" in got["Content-Disposition"] and "payroll.pdf" in got["Content-Disposition"]
    assert got["X-Content-Type-Options"] == "nosniff"
    denied = team.out_d.api.client.get(f"/api/files/{data['id']}", HTTP_AUTHORIZATION=f"Bearer {team.out_d.token}")
    assert denied.status_code == 404
    assert [f["id"] for f in team.cat_d.call("get", f"/subjects/{task['subject_id']}/files").data] == [data["id"]]
    assert team.cat_d.call("get", f"/tasks/{task['id']}").data["file_count"] == 1


def test_file_name_is_made_safe(team, task):
    data = upload(team.cat_d, task, name='..\\..\\evil"\r\nname.pdf').json()
    assert data["name"] == 'evil"name.pdf'
    row = File.objects.get(pk=data["id"])
    resp = team.cat_d.api.client.get(f"/api/files/{row.id}", HTTP_AUTHORIZATION=f"Bearer {team.cat_d.token}")
    assert "\r" not in resp["Content-Disposition"] and "\n" not in resp["Content-Disposition"]
    unicode_name = upload(team.cat_d, task, name="گزارش.pdf").json()
    resp = team.cat_d.api.client.get(f"/api/files/{unicode_name['id']}",
                                     HTTP_AUTHORIZATION=f"Bearer {team.cat_d.token}")
    assert "filename*=" in resp["Content-Disposition"]


def test_file_limits(team, task, settings):
    assert upload(team.cat_d, task, ctype="text/html").status_code == 422
    assert upload(team.cat_d, task, data=b"").status_code == 422
    settings.MAX_ATTACHMENT_BYTES = 10
    assert upload(team.cat_d, task).status_code == 413
    settings.MAX_ATTACHMENT_BYTES = 1000
    for _ in range(20):
        assert upload(team.cat_d, task).status_code == 201
    assert upload(team.cat_d, task).status_code == 422
    assert upload(team.out_d, task).status_code == 404


def test_file_deactivate_by_uploader_or_moderator(team, task):
    mine = upload(team.fay_d, task).json()
    other = upload(team.fay_d, task).json()
    assert team.olga_d.call("delete", f"/files/{mine['id']}").status_code == 403
    assert team.fay_d.call("delete", f"/files/{mine['id']}").status_code == 204
    assert team.cat_d.call("delete", f"/files/{other['id']}").status_code == 204
    assert team.cat_d.call("get", f"/subjects/{task['subject_id']}/files").data == []
    gone = team.cat_d.api.client.get(f"/api/files/{mine['id']}", HTTP_AUTHORIZATION=f"Bearer {team.cat_d.token}")
    assert gone.status_code == 404
    assert File.objects.filter(active=False).count() == 2
    assert upload(team.cat_d, task).status_code == 201  # inactive files do not count toward the limit


def test_file_event_goes_to_audience(team, task):
    upload(team.fay_d, task)
    ev = Event.objects.get(kind="file.added")
    assert set(EventRecipient.objects.filter(event=ev).values_list("user_id", flat=True)) == {team.cat.id, team.olga.id}


def test_seen_endpoints(team, task):
    path = f"/subjects/{task['subject_id']}/seen"
    assert team.out_d.call("get", path).status_code == 404 and team.out_d.call("post", path).status_code == 404
    assert team.fay_d.call("post", path).status_code == 204
    assert team.fay_d.call("post", path).status_code == 204  # idempotent, moves last_at
    rows = team.olga_d.call("get", path).data  # anyone who can see may ask who has seen it
    assert {r["user"]["id"] for r in rows} == {team.cat.id, team.fay.id}
    assert SeenBy.objects.filter(user=team.fay).count() == 1
    fay = next(r for r in rows if r["user"]["id"] == team.fay.id)
    assert fay["first_at"] <= fay["last_at"]


def test_history_endpoint_pages_newest_first(team, task):
    team.cat_d.call("patch", f"/tasks/{task['id']}", {"version": 1, "title": "B"})
    team.cat_d.call("patch", f"/tasks/{task['id']}", {"version": 2, "title": "C"})
    path = f"/subjects/{task['subject_id']}/history"
    rows = team.fay_d.call("get", path).data
    assert rows[0]["new"] == "C" and rows[0]["actor"]["id"] == team.cat.id and rows[-1]["field"] == "status"
    assert len(team.fay_d.call("get", f"{path}?limit=1").data) == 1


def test_generic_endpoints_on_a_dummy_module(team, dummy, make_user, login):
    subject = dummy.add(see=[team.fay], edit=[team.cat])
    path = f"/subjects/{subject.id}"
    assert team.cat_d.call("post", f"{path}/comments", {"body": {"text": "hi"}}).status_code == 201
    assert team.fay_d.call("post", f"{path}/comments", {"body": {"text": "hi"}}).status_code == 403  # sees, no act
    assert team.fay_d.call("get", f"{path}/comments").status_code == 200
    assert team.out_d.call("get", f"{path}/comments").status_code == 404
    assert upload(team.fay_d, {"subject_id": subject.id}).status_code == 403
    assert team.fay_d.call("get", f"{path}/seen").status_code == 200
    # no set_progress / audience on the dummy: reports are refused, events have no recipients
    assert team.cat_d.call("post", f"{path}/comments", {"body": {"text": "r"}, "kind": "report"}).status_code == 422
    ev = Event.objects.get(kind="comment.created")
    assert EventRecipient.objects.filter(event=ev).count() == 0


def test_comment_and_file_tables_stay_undeletable(team, task):
    team.cat_d.call("post", comments(task), {"body": {"text": "x"}})
    upload(team.cat_d, task)
    for table in ("workspace_comment", "workspace_file"):
        with pytest.raises(Exception, match="not allowed"), transaction.atomic():
            with connection.cursor() as cur:
                cur.execute(f"DELETE FROM {table}")
