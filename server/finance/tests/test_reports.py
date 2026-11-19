from datetime import timedelta

from finance.reports import today

from .conftest import doc_body


def add(d, **over):
    resp = d.call("post", "/finance/docs", doc_body(**over))
    assert resp.status_code == 201, resp.content
    return resp.data


def seed(d):
    add(d, amount=100, date="2026-05-10")  # confirmed receipt
    add(d, amount=30, direction="payment", date="2026-05-12")  # confirmed payment
    add(d, kind="probable", amount=50, due_date="2026-05-20", date="2026-05-01")  # probable receipt (past: overdue)
    add(d, kind="cheque", amount=20, direction="payment", due_date="2026-05-25", date="2026-05-02")
    void = add(d, amount=9999, date="2026-05-11")
    d.call("post", f"/finance/docs/{void['id']}/void", {"reason": "x"})


def test_summary_math_confirmed_probable_overdue_net(team):
    seed(team.fin_d)
    data = team.fin_d.call("get", "/finance/summary?from=2026-05-01&to=2026-05-31").data
    assert len(data["buckets"]) == 1
    b = data["buckets"][0]
    assert b["period"] == "2026-05" and (b["start"], b["end"]) == ("2026-05-01", "2026-05-31")
    assert (b["confirmed_receipts"], b["confirmed_payments"]) == (100, 30)
    assert (b["probable_receipts"], b["probable_payments"]) == (50, 20)
    assert (b["overdue_receipts"], b["overdue_payments"]) == (50, 20)  # both due dates are in the past
    assert b["net"] == 70 and b["projected_net"] == 100
    assert b["counts"]["confirmed_receipts"] == 1 and data["totals"]["net"] == 70
    assert b["jalali_year"] == 1405 and b["jalali_month"] == 2  # 2026-05-01 = 11 Ordibehesht 1405


def test_not_overdue_when_due_in_future(team):
    add(team.fin_d, kind="probable", amount=5, due_date=(today() + timedelta(days=3)).isoformat())
    totals = team.fin_d.call("get", "/finance/summary").data["totals"]
    assert totals["probable_receipts"] == 5 and totals["overdue_receipts"] == 0


def test_summary_year_and_validation(team):
    d = team.fin_d
    add(d, amount=1, date="2025-12-31")
    add(d, amount=2, date="2026-01-01")
    years = d.call("get", "/finance/summary?group_by=year").data["buckets"]
    assert [(y["period"], y["confirmed_receipts"]) for y in years] == [("2025", 1), ("2026", 2)]
    assert d.call("get", "/finance/summary?group_by=week").status_code == 422
    assert d.call("get", "/finance/summary?from=2026-02-01&to=2026-01-01").status_code == 422
    assert d.call("get", "/finance/summary?from=1900-01-01&to=2026-01-01").status_code == 422  # too many periods


def test_jalali_bucketing_across_year_boundary(team):
    d = team.fin_d
    add(d, amount=10, date="2026-03-20")  # 30 Esfand 1404 (last day)
    add(d, amount=20, date="2026-03-21")  # 1 Farvardin 1405
    data = d.call("get", "/finance/summary?calendar=jalali&from=2026-02-01&to=2026-04-30").data
    rows = {(b["jalali_year"], b["jalali_month"]): b for b in data["buckets"]}
    assert rows[(1404, 12)]["confirmed_receipts"] == 10 and rows[(1405, 1)]["confirmed_receipts"] == 20
    assert rows[(1404, 11)]["confirmed_receipts"] == 0  # gaps are filled
    assert rows[(1405, 1)]["start"] == "2026-03-21"
    monthly = d.call("get", "/finance/monthly?year=1405").data
    assert len(monthly["months"]) == 12 and monthly["months"][0]["month"] == 1
    assert monthly["months"][0]["confirmed_receipts"] == 20 and monthly["months"][0]["counts"]["confirmed_receipts"] == 1
    assert monthly["totals"]["confirmed_receipts"] == 20
    assert d.call("get", "/finance/monthly?year=1404").data["months"][11]["confirmed_receipts"] == 10
    assert d.call("get", "/finance/monthly?year=99999").status_code == 422


def test_gregorian_bucket_carries_jalali_fields_of_its_start(team):
    add(team.fin_d, amount=1, date="2026-03-25")
    b = team.fin_d.call("get", "/finance/summary?from=2026-03-01&to=2026-03-31").data["buckets"][0]
    assert (b["jalali_year"], b["jalali_month"]) == (1404, 12)  # March 1st is in Esfand 1404


def test_chart_series_and_label_filter(team):
    d = team.fin_d
    add(d, amount=7, date="2026-04-10")
    add(d, amount=3, direction="payment", date="2026-05-10")
    chart = d.call("get", "/finance/chart?from=2026-03-21&to=2026-05-31").data
    assert chart["labels"] == ["1405-01", "1405-02", "1405-03"]
    assert chart["receipts"] == [7, 0, 0] and chart["payments"] == [0, 3, 0]
    assert chart["points"][0]["jalali_month"] == 1
    assert len(d.call("get", "/finance/chart").data["labels"]) >= 12
    lab = team.boss.call("post", "/labels", {"name": "x", "scope": "org"}).data
    assert d.call("get", f"/finance/summary?label={lab['id']}&from=2026-04-01&to=2026-04-30").data["totals"]["net"] == 0


def test_reports_hide_documents_of_customers_the_caller_is_not_in(team, customer):
    add(team.fin_d, amount=100, customer_id=customer["id"])
    add(team.fin_d, amount=1)
    assert team.fin_d.call("get", "/finance/summary").data["totals"]["confirmed_receipts"] == 101
    assert team.fin2_d.call("get", "/finance/summary").data["totals"]["confirmed_receipts"] == 1
    assert team.fin_d.call("get", f"/customers/{customer['id']}/finance").data["totals"]["confirmed_receipts"] == 100
