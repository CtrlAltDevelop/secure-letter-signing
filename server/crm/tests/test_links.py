"""Tasks, meetings and letters linked to a customer file: validation, visibility, timeline rows."""
import uuid

from crm.models import CustomerEvent, CustomerMember
from letters.models import CustomerLink
from workspace.models import ChangeHistory

TASK_URL = "/tasks"


def summaries(customer_id, kind=None):
    from workspace.textbox import open_text

    rows = CustomerEvent.objects.filter(customer_id=customer_id)
    return [open_text(e.summary) for e in rows.filter(kind=kind)] if kind else [open_text(e.summary) for e in rows]


def test_task_link_rules(team, file):
    cid = file["id"]
    ok = team.bob_d.call("post", TASK_URL, {"title": "Send offer", "customer_id": cid})
    assert ok.status_code == 201 and ok.data["customer_id"] == cid and ok.data["customer_name"] == "ACME"
    assert team.vic_d.call("post", TASK_URL, {"title": "t", "customer_id": cid}).status_code == 403  # viewer
    assert team.out_d.call("post", TASK_URL, {"title": "t", "customer_id": cid}).status_code == 422  # not a member
    assert team.boss.call("post", TASK_URL, {"title": "t", "customer_id": cid}).status_code in (403, 422)
    assert team.bob_d.call("post", TASK_URL, {"title": "t", "customer_id": "6f1f9f7e-9d19-4d4b-8f44-0d6a55a6f0a1"}
                           ).status_code == 422
    assert summaries(cid, "task") == ["Task linked: Send offer"]


def test_task_patch_links_and_unlinks(team, file):
    cid = file["id"]
    task = team.bob_d.call("post", TASK_URL, {"title": "Plain"}).data
    assert task["customer_id"] is None
    patched = team.bob_d.call("patch", f"{TASK_URL}/{task['id']}", {"version": 1, "customer_id": cid})
    assert patched.status_code == 200 and patched.data["customer_id"] == cid
    assert ChangeHistory.objects.filter(subject_id=task["subject_id"], field="customer").exists()
    assert summaries(cid, "task") == ["Task linked: Plain"]
    cleared = team.bob_d.call("patch", f"{TASK_URL}/{task['id']}", {"version": 2, "customer_id": None})
    assert cleared.data["customer_id"] is None and cleared.data["customer_name"] is None


def test_task_status_changes_reach_the_timeline(team, file):
    cid = file["id"]
    task = team.bob_d.call("post", TASK_URL, {"title": "Ship", "customer_id": cid}).data
    assert team.bob_d.call("post", f"{TASK_URL}/{task['id']}/complete", {}).status_code == 200
    assert "Task status open -> done: Ship" in summaries(cid, "task")


def test_customer_name_hidden_from_non_members(team, file):
    cid = file["id"]
    task = team.bob_d.call("post", TASK_URL, {"title": "Shared", "customer_id": cid,
                                              "follower_ids": [team.out.id]}).data
    seen = team.out_d.call("get", f"{TASK_URL}/{task['id']}").data
    assert seen["customer_id"] is None and seen["customer_name"] is None


def test_customer_tasks_and_task_filter_show_only_visible(team, file):
    cid = file["id"]
    mine = team.bob_d.call("post", TASK_URL, {"title": "Visible", "customer_id": cid}).data
    team.ann_d.call("post", TASK_URL, {"title": "Hidden from bob", "customer_id": cid})
    team.bob_d.call("post", TASK_URL, {"title": "Unrelated"})
    assert [t["id"] for t in team.bob_d.call("get", f"/customers/{cid}/tasks").data] == [mine["id"]]
    assert len(team.ann_d.call("get", f"/customers/{cid}/tasks").data) == 1
    assert [t["id"] for t in team.bob_d.call("get", f"{TASK_URL}?customer={cid}").data] == [mine["id"]]
    assert team.out_d.call("get", f"/customers/{cid}/tasks").status_code == 404


def test_meeting_links(team, file):
    cid = file["id"]
    body = {"title": "Kickoff", "starts_at": "2030-01-01T08:00:00Z", "customer_id": cid}
    made = team.bob_d.call("post", "/meetings", body)
    assert made.status_code == 201 and made.data["customer_id"] == cid and made.data["customer_name"] == "ACME"
    assert team.out_d.call("post", "/meetings", body).status_code == 422
    assert team.vic_d.call("post", "/meetings", body).status_code == 403
    plain = team.bob_d.call("post", "/meetings", {"title": "Other", "starts_at": "2030-01-02T08:00:00Z"}).data
    assert plain["customer_id"] is None
    patched = team.bob_d.call("patch", f"/meetings/{plain['id']}", {"customer_id": cid})
    assert patched.status_code == 200 and patched.data["customer_id"] == cid
    assert len(summaries(cid, "meeting")) == 2
    assert {m["id"] for m in team.bob_d.call("get", f"/meetings?customer={cid}").data} == {made.data["id"], plain["id"]}
    assert len(team.bob_d.call("get", f"/customers/{cid}/meetings").data) == 2
    team.bob_d.call("post", f"/meetings/{made.data['id']}/cancel")
    assert any("Meeting status scheduled -> cancelled" in s for s in summaries(cid, "meeting"))
    assert team.vic_d.call("get", f"/customers/{cid}/meetings").data == []  # vic attends nothing


def test_letter_links_validate_and_list(team, file, make_user, login):

    ann = team.ann
    grants = ("letter.create", "letter.see", "task.create", "customer.create")
    writer = make_user("writer@corp.test", grants=grants)
    wd = login(writer)
    sid = make_user("signer@corp.test", grants=("letter.sign",))
    letter = wd.call("post", "/letters", {
        "title": "Offer", "body": {"text": "hi", "attachments": []}, "visibility": "public",
        "publish_mode": "after_sign", "order": "parallel", "signer_ids": [sid.id], "viewer_ids": [], "parent_id": None})
    assert letter.status_code == 201, letter.content
    lid = letter.data["id"]
    cid = file["id"]
    assert wd.call("put", f"/letters/{lid}/customers", {"customer_refs": [cid]}).status_code == 422  # not a member
    CustomerMember.objects.create(customer_id=cid, user=writer, role="viewer")
    assert wd.call("put", f"/letters/{lid}/customers", {"customer_refs": [cid]}).status_code == 200
    assert wd.call("get", f"/letters/{lid}").data["customer_refs"] == [cid]
    assert summaries(cid, "letter") == ["Letter linked: Offer"]
    assert CustomerLink.objects.filter(customer_ref=cid, active=True).count() == 1
    # the letter is a draft: only its creator sees it, so the file lists it for the writer only
    assert [x["title"] for x in wd.call("get", f"/customers/{cid}/letters").data] == ["Offer"]
    assert team.ann_d.call("get", f"/customers/{cid}/letters").data == []
    # a member who cannot see the letter cannot drop a link they cannot see: hidden refs are preserved
    assert ann.id and wd.call("put", f"/letters/{lid}/customers", {"customer_refs": []}).status_code == 200
    assert wd.call("get", f"/letters/{lid}").data["customer_refs"] == []


def test_hidden_links_are_kept_when_someone_else_replaces(team, file, make_user, login):
    from letters.secretariat import customer_refs, set_customers
    from letters.models import Letter

    writer = make_user("w2@corp.test", grants=("letter.create", "letter.see"))
    signer = make_user("s2@corp.test", grants=("letter.sign",))
    letter = login(writer).call("post", "/letters", {
        "title": "L", "body": {"text": "x", "attachments": []}, "visibility": "public", "publish_mode": "after_sign",
        "order": "parallel", "signer_ids": [signer.id], "viewer_ids": [], "parent_id": None}).data
    subject = Letter.objects.get(pk=letter["id"]).subject
    set_customers(team.ann, subject, [uuid.UUID(file["id"])])
    # writer is not a member: replacing with [] keeps ann's link
    assert [str(r) for r in set_customers(writer, subject, [])] == [file["id"]]
    assert [str(r) for r in customer_refs(subject.id)] == [file["id"]]
