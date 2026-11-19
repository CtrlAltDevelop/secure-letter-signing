import pytest
from django.db import transaction

from accounts.models import AuditEvent
from crm.models import CustomerEvent
from workspace.models import ChangeHistory, Event, EventRecipient
from workspace.textbox import open_text

from sales.models import Lead

from .conftest import lead_body


def make(d, **over):
    resp = d.call("post", "/sales/leads", lead_body(**over))
    assert resp.status_code == 201, resp.content
    return resp.data


def test_everything_404_without_grant(team):
    lead = make(team.ann_d)
    for method, path, body in [("get", "/sales/leads", None), ("post", "/sales/leads", lead_body()),
                               ("get", f"/sales/leads/{lead['id']}", None),
                               ("patch", f"/sales/leads/{lead['id']}", {"value": 1}),
                               ("post", f"/sales/leads/{lead['id']}/win", None), ("get", "/sales/summary", None)]:
        for who in (team.plain_d, team.boss):
            assert who.call(method, path, body).status_code == 404, (method, path)


def test_shared_visibility_default_and_private_mode(team, settings):
    lead = make(team.ann_d, owner_id=team.bob.id)
    assert team.cat_d.call("get", f"/sales/leads/{lead['id']}").status_code == 200  # shared by default
    assert team.cat_d.call("patch", f"/sales/leads/{lead['id']}", {"value": 5}).status_code == 403  # not owner/creator
    assert team.cat_d.call("post", f"/sales/leads/{lead['id']}/win").status_code == 403
    settings.SALES_SHARED_VISIBILITY = False
    assert team.cat_d.call("get", f"/sales/leads/{lead['id']}").status_code == 404
    assert team.cat_d.call("get", "/sales/leads").data == []
    assert team.bob_d.call("get", f"/sales/leads/{lead['id']}").status_code == 200  # owner
    assert team.ann_d.call("get", f"/sales/leads/{lead['id']}").status_code == 200  # creator


def test_customer_membership_required(team, customer):
    lead = make(team.ann_d, customer_id=customer["id"], owner_id=team.bob.id)
    assert lead["customer_name"] == "ACME"
    assert team.cat_d.call("get", f"/sales/leads/{lead['id']}").status_code == 404
    assert team.cat_d.call("get", "/sales/leads").data == []
    assert team.cat_d.call("post", "/sales/leads", lead_body(customer_id=customer["id"])).status_code == 422
    assert team.cat_d.call("get", f"/customers/{customer['id']}/leads").status_code == 404
    assert [x["id"] for x in team.bob_d.call("get", f"/customers/{customer['id']}/leads").data] == [lead["id"]]
    # plain is a member but has no sales.manage
    assert team.plain_d.call("get", f"/customers/{customer['id']}/leads").status_code == 404


def test_owner_rules(team, customer):
    assert team.ann_d.call("post", "/sales/leads", lead_body(owner_id=team.plain.id)).status_code == 422  # no grant
    assert team.ann_d.call("post", "/sales/leads", lead_body(owner_id=9999)).status_code == 422
    resp = team.ann_d.call("post", "/sales/leads", lead_body(customer_id=customer["id"], owner_id=team.cat.id))
    assert resp.status_code == 422  # owner must be on the customer file
    lead = make(team.ann_d)
    assert lead["owner"]["id"] == team.ann.id
    assert team.ann_d.call("patch", f"/sales/leads/{lead['id']}", {"owner_id": team.bob.id}).data["owner"]["id"] == team.bob.id
    assert team.ann_d.call("patch", f"/sales/leads/{lead['id']}", {"owner_id": team.plain.id}).status_code == 422


def test_win_lose_reopen_history_and_state_rules(team, customer):
    lead = make(team.ann_d, customer_id=customer["id"], description={"text": "private note"})
    path = f"/sales/leads/{lead['id']}"
    assert team.ann_d.call("post", path + "/reopen").status_code == 409
    assert team.ann_d.call("post", path + "/lose", {"reason": " "}).status_code == 422
    lost = team.ann_d.call("post", path + "/lose", {"reason": "too expensive"}).data
    assert lost["status"] == "lost" and lost["lost_reason"]["text"] == "too expensive" and lost["closed_at"]
    assert "too expensive" not in str(Lead.objects.get(pk=lead["id"]).lost_reason)
    assert team.ann_d.call("post", path + "/win").status_code == 409
    assert team.ann_d.call("patch", path, {"value": 2}).status_code == 409
    reopened = team.ann_d.call("post", path + "/reopen").data
    assert reopened["status"] == "open" and reopened["closed_at"] is None and reopened["lost_reason"] is None
    assert team.ann_d.call("post", path + "/win").data["status"] == "won"
    assert team.ann_d.call("post", path + "/reopen").data["status"] == "open"
    rows = ChangeHistory.objects.filter(subject_id=lead["subject_id"], field="status").order_by("id")
    assert [(r.old, r.new) for r in rows] == [(None, "open"), ("open", "lost"), ("lost", "open"), ("open", "won"),
                                              ("won", "open")]
    hist = team.ann_d.call("get", path + "/history").data
    assert {h["field"] for h in hist} >= {"status", "lost_reason"}
    reason = [h for h in hist if h["field"] == "lost_reason"][0]
    assert reason["new"] == {"changed": True}
    kinds = list(CustomerEvent.objects.filter(customer_id=customer["id"], kind="lead").order_by("id"))
    assert len(kinds) == 5 and all("Big deal" not in open_text(e.summary) for e in kinds)
    assert not any("Big deal" in str(a.data) or "too expensive" in str(a.data) for a in AuditEvent.objects.all())


def test_patch_fields_and_validation(team):
    lead = make(team.ann_d, description={"text": "a"})
    path = f"/sales/leads/{lead['id']}"
    out = team.ann_d.call("patch", path, {"title": "New", "value": 7, "probability": 80,
                                          "description": {"text": "b"}}).data
    assert (out["title"], out["value"], out["probability"], out["weighted_value"]) == ("New", 7, 80, 5)
    assert team.ann_d.call("patch", path, {"probability": 101}).status_code == 422
    assert team.ann_d.call("post", "/sales/leads", lead_body(value=-1)).status_code == 422
    assert open_text(Lead.objects.get(pk=lead["id"]).description) == "b"


def test_list_filters_and_probability_bucket(team, customer):
    a = make(team.ann_d, title="alpha", probability=10, value=100)
    b = make(team.ann_d, title="beta", probability=60, value=200, customer_id=customer["id"], owner_id=team.bob.id)
    c = make(team.ann_d, title="gamma", probability=100, value=300)
    team.ann_d.call("post", f"/sales/leads/{c['id']}/win")
    d = team.ann_d

    def ids(qs):
        return {x["id"] for x in d.call("get", "/sales/leads?" + qs).data}

    assert ids("owner=" + str(team.bob.id)) == {b["id"]}
    assert ids("customer=" + customer["id"]) == {b["id"]}
    assert ids("status=won") == {c["id"]} and ids("status=open,won") == {a["id"], b["id"], c["id"]}
    assert ids("min_prob=50&max_prob=90") == {b["id"]}
    assert ids("q=alp") == {a["id"]} and ids("q=acme") == {b["id"]}
    assert ids("probability_bucket=75-100") == set()  # buckets default to open leads
    assert ids("probability_bucket=75-100&status=won") == {c["id"]}
    assert ids("probability_bucket=0-24") == {a["id"]} and ids("probability_bucket=50-74") == {b["id"]}
    assert len(d.call("get", "/sales/leads?limit=1").data) == 1


def test_summary_weighted_pipeline_and_groups(team):
    make(team.ann_d, value=1000, probability=50)  # weighted 500
    make(team.ann_d, value=333, probability=30)  # 99.9
    make(team.bob_d, value=200, probability=80)  # 160
    make(team.bob_d, value=5, probability=0)
    won = make(team.bob_d, value=700, probability=100)
    lost = make(team.ann_d, value=40, probability=10)
    team.bob_d.call("post", f"/sales/leads/{won['id']}/win")
    team.ann_d.call("post", f"/sales/leads/{lost['id']}/lose", {"reason": "x"})
    s = team.cat_d.call("get", "/sales/summary").data
    assert s["won"] == {"count": 1, "value": 700} and s["lost"] == {"count": 1, "value": 40}
    assert s["open"] == {"count": 4, "value": 1538, "weighted": (50000 + 9990 + 16000) // 100}
    assert s["by_status"] == {"open": 4, "won": 1, "lost": 1}
    buckets = {b["bucket"]: b for b in s["by_probability"]}
    assert [buckets[k]["count"] for k in ("0-24", "25-49", "50-74", "75-100")] == [1, 1, 1, 1]
    assert buckets["75-100"]["weighted"] == 160 and buckets["0-24"]["value"] == 5
    assert len(s["won_by_month"]) == 1 and s["won_by_month"][0]["value"] == 700
    assert s["won_by_month"][0]["jalali_year"] >= 1405
    owners = {o["owner"]["id"]: o for o in s["by_owner"]}
    assert owners[team.bob.id]["open"]["count"] == 2 and owners[team.bob.id]["won"]["value"] == 700
    assert owners[team.ann.id]["lost"]["count"] == 1


def test_events_go_to_the_owner(team, django_capture_on_commit_callbacks):
    with django_capture_on_commit_callbacks(execute=True):
        lead = make(team.ann_d, owner_id=team.bob.id)
        team.ann_d.call("post", f"/sales/leads/{lead['id']}/win")
        mine = make(team.ann_d)
    kinds = [e.kind for e in Event.objects.filter(module="sales").order_by("id")]
    assert kinds == ["lead.created", "lead.won"]  # nothing for ann's own lead
    for e in Event.objects.filter(module="sales"):
        assert list(EventRecipient.objects.filter(event=e).values_list("user_id", flat=True)) == [team.bob.id]
    assert mine["owner"]["id"] == team.ann.id


def test_module_off_and_no_delete(team, brand_dir):
    lead = make(team.ann_d)
    with pytest.raises(Exception), transaction.atomic():
        Lead.objects.filter(pk=lead["id"]).delete()
    brand_dir(modules=["letters"])
    assert team.ann_d.call("get", "/sales/leads").status_code == 404
    assert team.ann_d.call("get", f"/sales/leads/{lead['id']}").status_code == 404
    assert team.ann_d.call("get", "/sales/summary").status_code == 404
