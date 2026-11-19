from datetime import timedelta

import pytest
from django.db import transaction

from accounts.models import AuditEvent
from crm.models import CustomerEvent
from workspace.models import ChangeHistory, Event, EventRecipient
from workspace.textbox import open_text

from finance.models import FinanceDoc
from finance.reports import today

from .conftest import doc_body


def create(d, **over):
    resp = d.call("post", "/finance/docs", doc_body(**over))
    assert resp.status_code == 201, resp.content
    return resp.data


def test_permission_matrix_everything_404_without_grant(team, customer):
    doc = create(team.fin_d)
    for method, path, body in [("get", "/finance/docs", None), ("post", "/finance/docs", doc_body()),
                               ("get", f"/finance/docs/{doc['id']}", None),
                               ("patch", f"/finance/docs/{doc['id']}", {"amount": 5}),
                               ("post", f"/finance/docs/{doc['id']}/void", {"reason": "x"}),
                               ("post", f"/finance/docs/{doc['id']}/confirm", {}),
                               ("get", "/finance/summary", None), ("get", "/finance/monthly?year=1405", None),
                               ("get", "/finance/chart", None),
                               ("get", f"/customers/{customer['id']}/finance", None),
                               ("get", f"/subjects/{doc['subject_id']}/history", None)]:
        for who in (team.plain_d, team.boss):
            assert who.call(method, path, body).status_code == 404, (method, path)


def test_customer_membership_required_on_top_of_grant(team, customer):
    linked = create(team.fin_d, customer_id=customer["id"])
    loose = create(team.fin_d)
    ids = {d["id"] for d in team.fin2_d.call("get", "/finance/docs").data}
    assert ids == {loose["id"]}  # fin2 holds the grant but is not on the customer file
    assert team.fin2_d.call("get", f"/finance/docs/{linked['id']}").status_code == 404
    assert team.fin2_d.call("post", "/finance/docs", doc_body(customer_id=customer["id"])).status_code == 422
    assert team.fin2_d.call("get", f"/customers/{customer['id']}/finance").status_code == 404
    assert team.fin_d.call("get", f"/customers/{customer['id']}/finance").data["documents"][0]["id"] == linked["id"]
    # plain is a customer member but lacks finance.manage
    assert team.plain_d.call("get", f"/customers/{customer['id']}/finance").status_code == 404


def test_create_validates_shape(team):
    d = team.fin_d
    assert d.call("post", "/finance/docs", doc_body(kind="cheque")).status_code == 422  # due_date required
    assert d.call("post", "/finance/docs", doc_body(kind="void")).status_code == 422
    assert d.call("post", "/finance/docs", doc_body(amount=0)).status_code == 422
    assert d.call("post", "/finance/docs", doc_body(direction="x")).status_code == 422
    assert d.call("post", "/finance/docs", doc_body(status="pending")).status_code == 422  # cash cannot be pending
    cheque = create(d, kind="cheque", due_date="2026-06-01")
    assert cheque["status"] == "pending"
    assert create(d)["status"] == "confirmed"


def test_description_encrypted_at_rest_and_timeline_without_amount(team, customer):
    doc = create(team.fin_d, customer_id=customer["id"], description={"text": "secret memo"}, amount=987654321)
    row = FinanceDoc.objects.get(pk=doc["id"])
    assert "secret memo" not in str(row.description) and open_text(row.description) == "secret memo"
    event = CustomerEvent.objects.get(customer_id=customer["id"], kind="finance")
    assert "987654321" not in open_text(event.summary)
    assert not any("987654321" in str(a.data) or "secret" in str(a.data) for a in AuditEvent.objects.all())


def test_patch_amount_history_and_customer_unlink(team, customer):
    doc = create(team.fin_d, customer_id=customer["id"], description={"text": "a"})
    resp = team.fin_d.call("patch", f"/finance/docs/{doc['id']}",
                           {"amount": 2_000_000, "description": {"text": "b"}, "customer_id": None})
    assert resp.status_code == 200 and resp.data["amount"] == 2_000_000 and resp.data["customer_id"] is None
    rows = {h.field: h for h in ChangeHistory.objects.filter(subject_id=doc["subject_id"])}
    assert rows["amount"].old == 1_000_000 and rows["amount"].new == 2_000_000
    assert rows["description"].new == {"changed": True} and rows["description"].old is None
    hist = team.fin_d.call("get", f"/finance/docs/{doc['id']}/history")
    assert {h["field"] for h in hist.data} >= {"amount", "description", "customer", "status"}


def test_void_flow_keeps_row_and_blocks_edits(team, customer, django_capture_on_commit_callbacks):
    doc = create(team.fin_d, customer_id=customer["id"])
    path = f"/finance/docs/{doc['id']}"
    assert team.fin_d.call("post", path + "/void", {"reason": ""}).status_code == 422
    with django_capture_on_commit_callbacks(execute=True):
        resp = team.fin_d.call("post", path + "/void", {"reason": "duplicate entry"})
    assert resp.status_code == 200
    assert resp.data["status"] == "void" and resp.data["void_reason"]["text"] == "duplicate entry"
    assert resp.data["voided_by"]["id"] == team.fin.id
    assert "duplicate entry" not in str(FinanceDoc.objects.get(pk=doc["id"]).void_reason)
    assert team.fin_d.call("post", path + "/void", {"reason": "again"}).status_code == 409
    assert team.fin_d.call("patch", path, {"amount": 5}).status_code == 409
    assert team.fin_d.call("post", path + "/confirm", {}).status_code == 409
    assert team.fin_d.call("get", path).data["status"] == "void"
    assert CustomerEvent.objects.filter(customer_id=customer["id"], kind="finance").count() == 2
    with pytest.raises(Exception), transaction.atomic():
        FinanceDoc.objects.filter(pk=doc["id"]).delete()


def test_events_go_to_the_creator_only(team):
    doc = create(team.fin_d)
    team.fin2_d.call("post", f"/finance/docs/{doc['id']}/void", {"reason": "oops"})
    events = Event.objects.filter(module="finance").order_by("id")
    assert [e.kind for e in events] == ["finance.created", "finance.voided"]
    for e in events:
        assert list(EventRecipient.objects.filter(event=e).values_list("user_id", flat=True)) == [team.fin.id]
        assert e.title == "" and "amount" not in e.data


def test_confirm_sets_actual_date(team):
    doc = create(team.fin_d, kind="probable", due_date="2026-07-01")
    resp = team.fin_d.call("post", f"/finance/docs/{doc['id']}/confirm", {"date": "2026-07-03"})
    assert resp.data["status"] == "confirmed" and resp.data["date"] == "2026-07-03"
    assert team.fin_d.call("post", f"/finance/docs/{doc['id']}/confirm", {}).status_code == 409
    other = create(team.fin_d, kind="cheque", due_date="2026-07-01")
    assert team.fin_d.call("post", f"/finance/docs/{other['id']}/confirm").data["date"] == today().isoformat()


def test_list_filters_and_search(team, customer):
    a = create(team.fin_d, customer_id=customer["id"], amount=111, description={"text": "rent october"})
    b = create(team.fin_d, kind="cheque", direction="payment", due_date="2026-08-01", amount=222)
    d = team.fin_d

    def ids(qs):
        return {x["id"] for x in d.call("get", "/finance/docs?" + qs).data}

    assert ids("customer=" + customer["id"]) == {a["id"]}
    assert ids("kind=cheque") == {b["id"]} and ids("direction=payment") == {b["id"]}
    assert ids("status=pending") == {b["id"]}
    assert ids("q=acme") == {a["id"]} and ids("q=october") == {a["id"]} and ids("q=222") == {b["id"]}
    assert ids("from=2026-07-15&to=2026-08-31") == {b["id"]}  # pending docs are placed by due_date
    assert ids("limit=1&offset=1") <= {a["id"], b["id"]} and len(ids("limit=1")) == 1


def test_labels_and_files_via_workspace_endpoints(team):
    doc = create(team.fin_d)
    lab = team.boss.call("post", "/labels", {"name": "tax", "scope": "org"})
    assert lab.status_code in (200, 201), lab.content
    resp = team.fin_d.call("put", f"/subjects/{doc['subject_id']}/labels", {"label_ids": [lab.data["id"]]})
    assert resp.status_code == 200, resp.content
    assert [x["id"] for x in team.fin_d.call("get", f"/finance/docs?label={lab.data['id']}").data] == [doc["id"]]
    assert team.plain_d.call("put", f"/subjects/{doc['subject_id']}/labels", {"label_ids": []}).status_code == 404


def test_module_off_is_404(team, brand_dir):
    doc = create(team.fin_d)
    brand_dir(modules=["letters"])
    for path in ("/finance/docs", f"/finance/docs/{doc['id']}", "/finance/summary"):
        assert team.fin_d.call("get", path).status_code == 404


def test_overdue_flag(team):
    late = create(team.fin_d, kind="cheque", due_date=(today() - timedelta(days=2)).isoformat())
    fresh = create(team.fin_d, kind="cheque", due_date=(today() + timedelta(days=2)).isoformat())
    assert late["overdue"] is True and fresh["overdue"] is False
