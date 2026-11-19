import json
from datetime import timedelta

from django.utils import timezone

from tasks.models import Task, TaskTemplate

BODY = {"title": "Weekly report", "description": "Fill the sheet", "priority": "high",
        "checklist": ["draft", "send"], "relative_due_days": 7, "owners": ["me"], "approvers": [], "followers": []}


def make(who, scope="personal", name="Weekly", **data):
    resp = who.call("post", "/task-templates", {"name": name, "scope": scope, "data": {**BODY, **data}})
    assert resp.status_code == 201, resp.content
    return resp.data


def test_create_list_patch_deactivate_and_encrypted_description(team):
    tpl = make(team.cat_d)
    assert tpl["scope"] == "personal" and tpl["owner_id"] == team.cat.id
    assert tpl["data"]["description"] == "Fill the sheet" and tpl["data"]["owners"] == ["me"]
    stored = TaskTemplate.objects.get(pk=tpl["id"]).data
    assert "Fill the sheet" not in json.dumps(stored) and stored["description"]["v"] == 3
    patched = team.cat_d.call("patch", f"/task-templates/{tpl['id']}", {"name": "Renamed", "active": False})
    assert patched.data["name"] == "Renamed" and patched.data["active"] is False
    assert team.cat_d.call("get", "/task-templates").data == []
    assert len(team.cat_d.call("get", "/task-templates?include_inactive=true").data) == 1
    assert TaskTemplate.objects.count() == 1


def test_personal_templates_are_private_org_ones_are_manager_only(team):
    mine = make(team.cat_d)
    org = make(team.boss, scope="org", name="Org")
    assert org["scope"] == "org" and org["owner_id"] is None
    assert team.cat_d.call("post", "/task-templates", {"name": "x", "scope": "org", "data": BODY}).status_code == 403
    assert [t["name"] for t in team.olga_d.call("get", "/task-templates").data] == ["Org"]
    assert sorted(t["name"] for t in team.cat_d.call("get", "/task-templates").data) == ["Org", "Weekly"]
    assert team.olga_d.call("patch", f"/task-templates/{mine['id']}", {"name": "z"}).status_code == 404
    assert team.cat_d.call("patch", f"/task-templates/{org['id']}", {"name": "z"}).status_code == 403
    assert team.boss.call("patch", f"/task-templates/{org['id']}", {"name": "Org2"}).status_code == 200


def test_template_validation(team):
    def post(**data):
        return team.cat_d.call("post", "/task-templates", {"name": "x", "data": {**BODY, **data}}).status_code

    assert post(owners=[99999]) == 422
    assert post(label_ids=[99999]) == 422
    assert post(checklist=[" "]) == 422
    assert post(owners=["you"]) == 422
    assert post(relative_due_days=-1) == 422
    assert post(owners=[team.olga.id, "me"]) == 201


def test_from_template_creates_a_task(team, django_capture_on_commit_callbacks):
    label = team.cat_d.call("post", "/labels", {"name": "ops", "scope": "personal"}).data
    tpl = make(team.cat_d, owners=["me", team.olga.id], approvers=[team.abe.id], followers=[team.fay.id],
               label_ids=[label["id"]])
    before = timezone.now()
    with django_capture_on_commit_callbacks(execute=True):
        resp = team.cat_d.call("post", "/tasks/from-template", {"template_id": tpl["id"]})
    assert resp.status_code == 201, resp.content
    task = resp.data
    assert task["title"] == "Weekly report" and task["priority"] == "high"
    assert task["description"] == {"text": "Fill the sheet"} and task["label_ids"] == [label["id"]]
    assert [i["text"] for i in task["checklist_items"]] == ["draft", "send"]
    assert sorted(o["id"] for o in task["owners"]) == sorted([team.cat.id, team.olga.id])
    assert [a["user"]["id"] for a in task["approvers"]] == [team.abe.id]
    assert [f["id"] for f in task["followers"]] == [team.fay.id]
    due = Task.objects.get(pk=task["id"]).due_at
    assert timedelta(days=6, hours=23) < due - before < timedelta(days=7, hours=1)
    assert task["creator"]["id"] == team.cat.id


def test_me_resolves_to_whoever_uses_an_org_template(team):
    org = make(team.boss, scope="org", name="Org", owners=["me"])
    task = team.olga_d.call("post", "/tasks/from-template", {"template_id": org["id"]}).data
    assert [o["id"] for o in task["owners"]] == [team.olga.id] and task["creator"]["id"] == team.olga.id


def test_overrides_replace_template_values(team):
    tpl = make(team.cat_d)
    due = (timezone.now() + timedelta(days=30)).isoformat()
    resp = team.cat_d.call("post", "/tasks/from-template", {
        "template_id": tpl["id"], "overrides": {"title": "Special", "due_at": due, "owner_ids": [team.olga.id],
                                                "weight": 3, "checklist": ["only"]}})
    assert resp.status_code == 201, resp.content
    task = resp.data
    assert task["title"] == "Special" and task["weight"] == 3 and task["priority"] == "high"
    assert [o["id"] for o in task["owners"]] == [team.olga.id]
    assert [i["text"] for i in task["checklist_items"]] == ["only"]
    assert task["due_at"][:10] == due[:10]


def test_bad_overrides_are_422(team):
    tpl = make(team.cat_d)
    for overrides in ({"nope": 1}, {"project_id": "x"}, {"priority": "huge"}, {"title": ""}):
        resp = team.cat_d.call("post", "/tasks/from-template", {"template_id": tpl["id"], "overrides": overrides})
        assert resp.status_code == 422, overrides


def test_from_template_access_rules(team, make_user, login):
    mine, org = make(team.cat_d), make(team.boss, scope="org", name="Org")
    assert team.olga_d.call("post", "/tasks/from-template", {"template_id": mine["id"]}).status_code == 404
    team.cat_d.call("patch", f"/task-templates/{mine['id']}", {"active": False})
    assert team.cat_d.call("post", "/tasks/from-template", {"template_id": mine["id"]}).status_code == 422
    plain = login(make_user("plain@corp.test"))
    assert plain.call("post", "/tasks/from-template", {"template_id": org["id"]}).status_code == 403


def test_inactive_people_and_hidden_labels_are_skipped_at_use_time(team):
    tpl = make(team.cat_d, owners=[team.olga.id], followers=[team.fay.id])
    team.fay.is_active = False
    team.fay.save()
    task = team.cat_d.call("post", "/tasks/from-template", {"template_id": tpl["id"]}).data
    assert task["followers"] == [] and [o["id"] for o in task["owners"]] == [team.olga.id]
