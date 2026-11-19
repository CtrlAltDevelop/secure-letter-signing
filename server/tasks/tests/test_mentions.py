from accounts.models import Notification
from workspace.models import Event, Mention


def post(who, task, text="hello", **extra):
    return who.call("post", f"/subjects/{task['subject_id']}/comments", {"body": {"text": text}, **extra})


def test_mention_stored_returned_and_notified(team, make_task, django_capture_on_commit_callbacks):
    task = make_task(follower_ids=[team.fay.id])
    with django_capture_on_commit_callbacks(execute=True):
        resp = post(team.cat_d, task, "please check", mentions=[team.fay.id, team.fay.id, team.cat.id])
    assert resp.status_code == 201
    assert sorted(m["id"] for m in resp.data["mentions"]) == sorted([team.fay.id, team.cat.id])
    assert {"title", "status_text"} <= set(resp.data["mentions"][0])
    assert Mention.objects.count() == 2
    assert Notification.objects.filter(user=team.fay, kind="mention").count() == 1
    assert not Notification.objects.filter(user=team.cat, kind="mention").exists()  # no self notification
    assert Event.objects.filter(kind="mention", recipients__user=team.fay).count() == 1
    listed = team.cat_d.call("get", f"/subjects/{task['subject_id']}/comments").data
    assert [m["id"] for m in listed[0]["mentions"]] == sorted([team.fay.id, team.cat.id])


def test_mentioning_someone_who_cannot_see_is_422(team, make_task):
    task = make_task()
    assert post(team.cat_d, task, mentions=[team.out.id]).status_code == 422
    assert post(team.cat_d, task, mentions=[999999]).status_code == 422
    assert Mention.objects.count() == 0


def test_inactive_user_cannot_be_mentioned(team, make_task):
    task = make_task(follower_ids=[team.fay.id])
    team.fay.is_active = False
    team.fay.save()
    assert post(team.cat_d, task, mentions=[team.fay.id]).status_code == 422


def test_reports_can_mention_and_edit_keeps_mentions(team, make_task):
    task = make_task(follower_ids=[team.fay.id])
    resp = post(team.olga_d, task, "done half", kind="report", progress=50, mentions=[team.fay.id])
    assert resp.status_code == 201 and resp.data["kind"] == "report"
    edited = team.olga_d.call("patch", f"/comments/{resp.data['id']}", {"body": {"text": "done 60%"}})
    assert [m["id"] for m in edited.data["mentions"]] == [team.fay.id]
    rows = team.fay_d.call("get", "/me/mentions").data
    assert len(rows) == 1 and rows[0]["excerpt"] == "done 60%" and rows[0]["report"] is True


def test_my_mentions_newest_first_paged_with_excerpt(team, make_task):
    task = make_task(follower_ids=[team.fay.id])
    for i in range(3):
        post(team.cat_d, task, f"note {i} " + "x" * 300, mentions=[team.fay.id])
    rows = team.fay_d.call("get", "/me/mentions").data
    assert [r["excerpt"][:6] for r in rows] == ["note 2", "note 1", "note 0"]
    assert len(rows[0]["excerpt"]) <= 140
    assert rows[0]["module"] == "tasks" and rows[0]["title"] == "Quarterly report"
    assert rows[0]["subject_id"] == task["subject_id"] and rows[0]["author"]["id"] == team.cat.id
    page = team.fay_d.call("get", "/me/mentions?limit=1&offset=1").data
    assert [r["excerpt"][:6] for r in page] == ["note 1"]
    assert team.cat_d.call("get", "/me/mentions").data == []


def test_mentions_hide_subjects_i_lost_access_to(team, make_task):
    task = make_task(follower_ids=[team.fay.id])
    post(team.cat_d, task, "secret", mentions=[team.fay.id])
    cur = team.cat_d.call("get", f"/tasks/{task['id']}").data
    people = {"owner_ids": [team.olga.id], "approver_ids": [], "follower_ids": []}
    assert team.cat_d.call("put", f"/tasks/{task['id']}/people", people).status_code == 200
    assert cur["version"] >= 1
    assert team.fay_d.call("get", "/me/mentions").data == []


def test_deactivated_comment_leaves_the_list(team, make_task):
    task = make_task(follower_ids=[team.fay.id])
    cid = post(team.cat_d, task, mentions=[team.fay.id]).data["id"]
    assert team.cat_d.call("delete", f"/comments/{cid}").status_code == 204
    assert team.fay_d.call("get", "/me/mentions").data == []
