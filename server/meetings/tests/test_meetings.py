import json

import pytest
from django.db import transaction
from django.db.utils import DatabaseError

from accounts.models import AuditEvent
from meetings.models import Meeting, MeetingMinutesSignature
from meetings.tests.conftest import PIN
from workspace.models import ChangeHistory, Event


def test_create_returns_out_and_encrypts_description(team, org_body):
    org_body["description"] = {"text": "secret agenda"}
    resp = team.cat_d.call("post", "/meetings", org_body)
    assert resp.status_code == 201
    data = resp.data
    assert data["status"] == "scheduled" and data["kind"] == "organizational" and data["revision"] == 1
    assert data["description"] == {"text": "secret agenda"} and len(data["attendees"]) == 4
    assert data["can"]["manage"] and data["can"]["chair"] and data["my_role"] == "chair"
    row = Meeting.objects.get(pk=data["id"])
    assert "secret agenda" not in json.dumps(row.description) and row.subject.module == "meetings"


def test_organizational_needs_exactly_one_chair_and_secretary(team, org_body):
    no_sec = {**org_body, "attendees": org_body["attendees"][:1]}
    assert team.cat_d.call("post", "/meetings", no_sec).status_code == 422
    two_chairs = {**org_body, "attendees": [*org_body["attendees"], {"user_id": team.out.id, "role": "chair"}]}
    assert team.cat_d.call("post", "/meetings", two_chairs).status_code == 422
    simple = {"title": "Quick", "starts_at": "2030-01-01T08:00:00Z"}
    assert team.cat_d.call("post", "/meetings", simple).status_code == 201


def test_scheduled_needs_start_and_draft_does_not(team):
    assert team.cat_d.call("post", "/meetings", {"title": "x"}).status_code == 422
    resp = team.cat_d.call("post", "/meetings", {"title": "x", "status": "draft"})
    assert resp.status_code == 201 and resp.data["status"] == "draft"
    assert team.cat_d.call("post", f"/meetings/{resp.data['id']}/schedule").status_code == 422


def test_visibility_creator_and_attendees_only(team, meeting):
    mid = meeting["id"]
    for who in (team.cat_d, team.sue_d, team.mia_d):
        assert who.call("get", f"/meetings/{mid}").status_code == 200
    assert team.out_d.call("get", f"/meetings/{mid}").status_code == 404
    assert team.boss.call("get", f"/meetings/{mid}").status_code == 404
    assert team.out_d.call("get", "/meetings").data == [] and team.boss.call("get", "/meetings").data == []
    assert len(team.mia_d.call("get", "/meetings?mine=true").data) == 1


def test_list_filters(team, meeting):
    team.cat_d.call("post", "/meetings", {"title": "Lunch", "starts_at": "2031-05-01T10:00:00Z"})
    ids = lambda path: [m["title"] for m in team.cat_d.call("get", path).data]  # noqa: E731
    assert ids("/meetings?q=lun") == ["Lunch"]
    assert ids("/meetings?kind=organizational") == ["Board"]
    assert ids("/meetings?status=draft") == []
    assert ids("/meetings?from=2031-01-01T00:00:00Z") == ["Lunch"]
    assert ids("/meetings?to=2030-12-31T00:00:00Z") == ["Board"]


def test_edit_fields_history_and_roles(team, meeting):
    mid = meeting["id"]
    assert team.mia_d.call("patch", f"/meetings/{mid}", {"location": "Room 2"}).status_code == 403
    resp = team.cat_d.call("patch", f"/meetings/{mid}", {"location": "Room 2", "title": "Board 2"})
    assert resp.status_code == 200 and resp.data["location"] == "Room 2"
    fields = set(ChangeHistory.objects.filter(subject__meeting__id=mid).values_list("field", flat=True))
    assert {"location", "title", "status"} <= fields
    assert team.sue_d.call("patch", f"/meetings/{mid}", {"description": {"text": "minutes"}}).status_code == 200
    hist = ChangeHistory.objects.get(subject__meeting__id=mid, field="description")
    assert hist.new == {"changed": True} and hist.old is None


def test_attendees_put_guests_and_attendance(team, meeting):
    mid = meeting["id"]
    people = [{"user_id": team.cat.id, "role": "chair"}, {"user_id": team.sue.id, "role": "secretary"},
              {"user_id": team.mia.id, "role": "member"}, {"guest_name": "Mr Outside", "role": "guest"}]
    resp = team.cat_d.call("put", f"/meetings/{mid}/attendees", people)
    assert resp.status_code == 200
    assert {a["guest_name"] for a in resp.data["attendees"]} == {"", "Mr Outside"}
    assert team.max_d.call("get", f"/meetings/{mid}").status_code == 404  # removed attendee loses access
    bad = [{"guest_name": "X", "role": "member"}, *people[:2]]
    assert team.cat_d.call("put", f"/meetings/{mid}/attendees", bad).status_code == 422
    guest = next(a for a in resp.data["attendees"] if a["guest_name"])
    assert team.mia_d.call("post", f"/meetings/{mid}/attendance",
                           {"attendee_id": guest["id"], "attendance": "present"}).status_code == 403
    ok = team.sue_d.call("post", f"/meetings/{mid}/attendance", {"attendee_id": guest["id"], "attendance": "present"})
    assert ok.status_code == 200


def test_hold_close_permissions_and_states(team, meeting):
    mid = meeting["id"]
    assert team.sue_d.call("post", f"/meetings/{mid}/hold").status_code == 403
    assert team.cat_d.call("post", f"/meetings/{mid}/close").status_code == 409
    assert team.cat_d.call("post", f"/meetings/{mid}/hold").data["status"] == "held"
    assert team.cat_d.call("post", f"/meetings/{mid}/cancel").status_code == 409
    assert team.cat_d.call("post", f"/meetings/{mid}/close").data["status"] == "closed"
    assert team.sue_d.call("post", f"/meetings/{mid}/resolutions", {"text": "late"}).status_code == 409
    actions = set(AuditEvent.objects.values_list("action", flat=True))
    assert {"meeting_created", "meeting_held", "meeting_closed"} <= actions
    assert not any("Board" in json.dumps(a.data) for a in AuditEvent.objects.filter(action__startswith="meeting_"))


def test_cancel_draft_or_scheduled(team, meeting):
    assert team.cat_d.call("post", f"/meetings/{meeting['id']}/cancel").data["status"] == "cancelled"
    assert Event.objects.filter(kind="meeting.cancelled").exists()


def test_resolution_creates_task_and_mirrors_completion(team, meeting):
    mid = meeting["id"]
    resp = team.sue_d.call("post", f"/meetings/{mid}/resolutions",
                           {"text": "Buy chairs\nasap", "owner_ids": [team.mia.id], "due_at": "2030-02-01T00:00:00Z"})
    assert resp.status_code == 201, resp.content
    res = resp.data
    assert res["task_id"] and res["task_status"] == "open" and res["owner_ids"] == [team.mia.id]
    task = team.mia_d.call("get", f"/tasks/{res['task_id']}").data
    assert task["title"] == "Buy chairs asap" and task["owner_ids"] == [team.mia.id]
    assert f"meeting:{mid}" in task["description"]["text"] and task["due_at"].startswith("2030-02-01")
    assert team.mia_d.call("post", f"/tasks/{res['task_id']}/complete", {}).status_code == 200
    out = team.cat_d.call("get", f"/meetings/{mid}").data
    assert out["resolution_items"][0]["status"] == "done" and out["resolutions"] == {"done": 1, "total": 1}
    assert ChangeHistory.objects.filter(subject__meeting__id=mid, field__endswith=":status").exists()


def test_resolution_edit_syncs_task_and_deactivate_cancels(team, meeting):
    mid = meeting["id"]
    res = team.sue_d.call("post", f"/meetings/{mid}/resolutions", {"text": "One", "owner_ids": [team.mia.id]}).data
    path = f"/meetings/{mid}/resolutions/{res['id']}"
    upd = team.cat_d.call("patch", path, {"text": "Two", "owner_ids": [team.mia.id, team.max.id]})
    assert upd.status_code == 200 and sorted(upd.data["owner_ids"]) == sorted([team.mia.id, team.max.id])
    task = team.max_d.call("get", f"/tasks/{res['task_id']}").data
    assert task["title"] == "Two"
    assert team.cat_d.call("patch", path, {"status": "done"}).status_code == 409
    assert team.cat_d.call("patch", path, {"owner_ids": []}).status_code == 422
    assert team.cat_d.call("patch", path, {"active": False}).status_code == 200
    assert team.mia_d.call("get", f"/tasks/{res['task_id']}").data["status"] == "cancelled"
    assert team.cat_d.call("get", f"/meetings/{mid}").data["resolution_items"] == []
    text_hist = ChangeHistory.objects.filter(subject__meeting__id=mid, field=f"resolution:{res['id']}:text")
    assert text_hist.exists() and all(h.new == {"changed": True} for h in text_hist)


def test_resolution_without_owners_has_no_task_and_manual_status(team, meeting):
    mid = meeting["id"]
    res = team.sue_d.call("post", f"/meetings/{mid}/resolutions", {"text": "Note it"}).data
    assert res["task_id"] is None
    done = team.sue_d.call("patch", f"/meetings/{mid}/resolutions/{res['id']}", {"status": "done"})
    assert done.data["status"] == "done"
    assert team.mia_d.call("post", f"/meetings/{mid}/resolutions", {"text": "x"}).status_code == 403


def test_resolution_in_project_meeting(team):
    proj = team.cat_d.call("post", "/projects", {"name": "P", "members": [
        {"user_id": team.mia.id, "role": "member"}, {"user_id": team.sue.id, "role": "member"}]}).data
    body = {"title": "PM", "starts_at": "2030-01-01T08:00:00Z", "project_id": proj["id"],
            "attendees": [{"user_id": team.sue.id, "role": "secretary"}, {"user_id": team.mia.id, "role": "member"}]}
    m = team.cat_d.call("post", "/meetings", body).data
    res = team.cat_d.call("post", f"/meetings/{m['id']}/resolutions", {"text": "Do", "owner_ids": [team.mia.id]})
    assert res.status_code == 201
    assert team.mia_d.call("get", f"/tasks/{res.data['task_id']}").data["project_id"] == proj["id"]
    outsider = team.cat_d.call("post", f"/meetings/{m['id']}/resolutions", {"text": "Do", "owner_ids": [team.out.id]})
    assert outsider.status_code == 422
    assert team.out_d.call("post", "/meetings", {**body, "attendees": []}).status_code == 404  # not a member


def test_sign_flow_pin_and_rules(team, meeting, held):
    mid = held["id"]
    sign = lambda who, **kw: who.call("post", f"/meetings/{mid}/sign", {"decision": "approved", "pin": PIN, **kw})  # noqa: E731
    assert team.max_d.call("post", f"/meetings/{mid}/sign", {"decision": "approved", "pin": PIN}).status_code == 403
    assert team.mia_d.call("post", f"/meetings/{mid}/sign", {"decision": "approved", "pin": "000000"}).status_code == 403
    assert team.mia_d.call("post", f"/meetings/{mid}/sign", {"decision": "rejected", "pin": PIN}).status_code == 422
    ok = sign(team.mia_d)
    assert ok.status_code == 200 and ok.data["signatures"][0]["valid"] and not ok.data["signatures"][0]["stale"]
    assert sign(team.mia_d).status_code == 409
    row = MeetingMinutesSignature.objects.get()
    assert row.payload["meetingId"] == mid and row.payload["revision"] == 1 and row.payload["method"] == "pin"
    assert len(row.payload["contentHash"]) == 64 and row.payload["nonce"] == row.nonce
    assert ok.data["content_hash"] == row.payload["contentHash"] and not ok.data["all_signed"]
    assert sign(team.cat_d).data["all_signed"] is True
    with pytest.raises(DatabaseError), transaction.atomic():
        MeetingMinutesSignature.objects.update(note="tamper")


def test_sign_before_hold_is_refused(team, meeting):
    mid = meeting["id"]
    team.sue_d.call("post", f"/meetings/{mid}/attendance", {"user_id": team.mia.id, "attendance": "present"})
    resp = team.mia_d.call("post", f"/meetings/{mid}/sign", {"decision": "approved", "pin": PIN})
    assert resp.status_code == 409


def test_signed_minutes_are_frozen_until_chair_reopens(team, held):
    mid = held["id"]
    team.mia_d.call("post", f"/meetings/{mid}/sign", {"decision": "approved", "pin": PIN})
    assert team.sue_d.call("patch", f"/meetings/{mid}", {"description": {"text": "edit"}}).status_code == 409
    assert team.sue_d.call("post", f"/meetings/{mid}/resolutions", {"text": "x"}).status_code == 409
    assert team.sue_d.call("post", f"/meetings/{mid}/attendance",
                           {"user_id": team.max.id, "attendance": "absent"}).status_code == 409
    assert team.sue_d.call("post", f"/meetings/{mid}/reopen").status_code == 403
    reopened = team.cat_d.call("post", f"/meetings/{mid}/reopen")
    assert reopened.data["revision"] == 2 and reopened.data["status"] == "held"
    assert reopened.data["signatures"][0]["stale"] is True and reopened.data["signatures"][0]["valid"]
    assert team.sue_d.call("patch", f"/meetings/{mid}", {"description": {"text": "edit"}}).status_code == 200
    again = team.mia_d.call("post", f"/meetings/{mid}/sign", {"decision": "approved", "pin": PIN})
    assert again.status_code == 200 and [s["stale"] for s in again.data["signatures"]] == [True, False]
    assert MeetingMinutesSignature.objects.filter(revision=2).get().payload["revision"] == 2
    assert team.cat_d.call("post", f"/meetings/{mid}/close").data["status"] == "closed"
    assert team.cat_d.call("post", f"/meetings/{mid}/reopen").data["revision"] == 3


def test_reopen_without_signatures_is_conflict(team, held):
    assert team.cat_d.call("post", f"/meetings/{held['id']}/reopen").status_code == 409


def test_sign_biometric_needs_biometric_session(team, held, api):
    mid = held["id"]
    body = {"decision": "approved"}
    assert team.mia_d.call("post", f"/meetings/{mid}/sign-biometric", body).status_code == 403
    assert team.mia_d.call("patch", "/me/sessions/current", {"biometric": True, "pin": PIN}).status_code == 200
    resp = team.mia_d.call("post", f"/meetings/{mid}/sign-biometric", body)
    assert resp.status_code == 200
    assert MeetingMinutesSignature.objects.get().method == "biometric"


def test_templates_and_create_from_template(team, org_body):
    data = {"kind": "organizational", "location": "HQ", "description": "Agenda",
            "attendees": [{"user_id": team.cat.id, "role": "chair"}, {"user_id": team.sue.id, "role": "secretary"}]}
    tpl = team.cat_d.call("post", "/meeting-templates", {"name": "Weekly", "data": data})
    assert tpl.status_code == 201 and tpl.data["scope"] == "personal"
    assert team.cat_d.call("post", "/meeting-templates", {"name": "Org", "scope": "org", "data": data}).status_code == 403
    assert team.boss.call("post", "/meeting-templates", {"name": "Org", "scope": "org", "data": data}).status_code == 201
    assert len(team.mia_d.call("get", "/meeting-templates").data) == 1  # only the org one
    resp = team.cat_d.call("post", "/meetings", {"template_id": tpl.data["id"], "starts_at": "2030-01-01T08:00:00Z"})
    assert resp.status_code == 201 and resp.data["title"] == "Weekly" and resp.data["location"] == "HQ"
    assert resp.data["description"]["text"] == "Agenda" and resp.data["template_id"] == tpl.data["id"]
    assert len(resp.data["attendees"]) == 2
    off = team.cat_d.call("patch", f"/meeting-templates/{tpl.data['id']}", {"active": False})
    assert off.data["active"] is False
    assert team.cat_d.call("post", "/meetings", {"template_id": tpl.data["id"], "starts_at": "2030-01-01T08:00:00Z"}).status_code == 422
    assert team.mia_d.call("patch", f"/meeting-templates/{tpl.data['id']}", {"name": "x"}).status_code == 404


def test_remind_creates_one_reminder_per_attendee(team, meeting):
    mid = meeting["id"]
    assert team.mia_d.call("post", f"/meetings/{mid}/remind", {"offset_minutes": 30}).status_code == 403
    resp = team.sue_d.call("post", f"/meetings/{mid}/remind", {"offset_minutes": 30})
    assert resp.status_code == 200 and resp.data == {"reminders": 4}
    assert team.sue_d.call("post", f"/meetings/{mid}/remind", {"offset_minutes": 30}).data == {"reminders": 0}
    mine = team.mia_d.call("get", f"/subjects/{meeting['subject_id']}/reminders").data
    assert len(mine) == 1 and mine[0]["at"].startswith("2030-01-01T07:30")
    assert team.sue_d.call("post", f"/meetings/{mid}/remind", {"offset_minutes": 60 * 24 * 365 * 9}).status_code == 422


class RecordingSms:
    sent: list = []

    def send(self, recipients, text):
        RecordingSms.sent.append((list(recipients), text))


def test_sms_goes_through_backend_and_audits_counts_only(team, meeting, settings):
    settings.SMS_BACKEND = "meetings.tests.test_meetings.RecordingSms"
    RecordingSms.sent.clear()
    mid = meeting["id"]
    assert team.sue_d.call("post", f"/meetings/{mid}/sms", {"text": "hi"}).status_code == 422  # nobody has a phone
    team.mia.phone, team.max.phone = "+989121234567", "09121234568"
    team.mia.save(update_fields=["phone"])
    team.max.save(update_fields=["phone"])
    assert team.mia_d.call("post", f"/meetings/{mid}/sms", {"text": "hi"}).status_code == 403
    resp = team.sue_d.call("post", f"/meetings/{mid}/sms", {"text": "Meeting at 8"})
    assert resp.status_code == 200 and resp.data == {"sent": 2, "without_phone": 2}
    assert sorted(RecordingSms.sent[0][0]) == ["+989121234567", "09121234568"]
    audit = AuditEvent.objects.get(action="meeting_sms")
    assert audit.data == {"recipients": 2} and "Meeting at 8" not in json.dumps(audit.data)


def test_console_sms_backend_logs_counts_only(caplog):
    import logging

    from core import sms

    with caplog.at_level(logging.INFO, logger="core.sms"):
        sms.send_sms(["+989121234567"], "secret text")
    assert "1 recipient" in caplog.text and "989121234567" not in caplog.text and "secret text" not in caplog.text


def test_profile_phone_roundtrip(team):
    me = team.mia_d.call("patch", "/me", {"phone": "+989121234567"})
    assert me.status_code == 200 and me.data["phone"] == "+989121234567"
    assert team.mia_d.call("patch", "/me", {"phone": "abc"}).status_code == 422
    assert team.mia_d.call("patch", "/me", {"phone": ""}).data["phone"] == ""


def test_module_off_is_404(team, brand_dir):
    brand_dir(modules=["tasks"])
    assert team.cat_d.call("get", "/meetings").status_code == 404
    assert team.cat_d.call("get", "/meeting-templates").status_code == 404


def test_shared_endpoints_work_on_meeting_subject(team, meeting):
    sid = meeting["subject_id"]
    assert team.mia_d.call("post", f"/subjects/{sid}/comments", {"body": {"text": "hello"}}).status_code == 201
    assert team.out_d.call("get", f"/subjects/{sid}/comments").status_code == 404
    label = team.mia_d.call("post", "/labels", {"name": "mine", "scope": "personal"}).data
    assert team.mia_d.call("put", f"/subjects/{sid}/labels", {"label_ids": [label["id"]]}).status_code == 200
    assert team.mia_d.call("get", f"/meetings/{meeting['id']}").data["label_ids"] == [label["id"]]
