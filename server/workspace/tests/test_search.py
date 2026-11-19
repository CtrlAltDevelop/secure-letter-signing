import pytest
from django.core.files.uploadedfile import SimpleUploadedFile

from letters.models import Letter
from workspace import registry, search


@pytest.fixture(autouse=True)
def _modules(brand_dir):
    brand_dir()


@pytest.fixture
def crew(make_user, login, manager):
    crew = type("Crew", (), {})()
    crew.manager, crew.boss = manager, login(manager)
    grants = ("task.create", "project.create", "customer.create", "chat.create_group")
    for name, extra in (("ann", ()), ("bob", ()), ("fin", ("finance.manage", "sales.manage")), ("out", ())):
        user = make_user(f"{name}@corp.test", grants=grants + extra)
        setattr(crew, name, user)
        setattr(crew, f"{name}_d", login(user))
    return crew


def find(who, q, **params):
    extra = "".join(f"&{k}={v}" for k, v in params.items())
    resp = who.call("get", f"/search?q={q}{extra}")
    assert resp.status_code == 200, resp.content
    return resp.data


def titles(rows):
    return sorted((r["module"], r["title"]) for r in rows)


def test_query_length_and_response_shape(crew):
    assert crew.ann_d.call("get", "/search?q=a").status_code == 422
    assert crew.ann_d.call("get", "/search").status_code == 422
    task = crew.ann_d.call("post", "/tasks", {"title": "Quarterly report"}).data
    [hit_] = find(crew.ann_d, "Quarterly")
    assert set(hit_) == {"module", "kind", "id", "subject_id", "title", "snippet", "at"}
    assert (hit_["module"], hit_["kind"], hit_["id"], hit_["subject_id"]) == (
        "tasks", "task", task["id"], task["subject_id"])


def test_tasks_labels_and_visibility(crew):
    mine = crew.ann_d.call("post", "/tasks", {"title": "Alpha plan"}).data
    crew.bob_d.call("post", "/tasks", {"title": "Alpha secret"})
    label = crew.ann_d.call("post", "/labels", {"name": "urgentish", "scope": "personal"}).data
    crew.ann_d.call("put", f"/subjects/{mine['subject_id']}/labels", {"label_ids": [label["id"]]})
    assert titles(find(crew.ann_d, "Alpha")) == [("tasks", "Alpha plan")]
    assert titles(find(crew.ann_d, "urgentish")) == [("tasks", "Alpha plan")]
    assert find(crew.bob_d, "urgentish") == []  # someone else's personal label
    assert find(crew.boss, "Alpha") == []


def test_projects_meetings_notes_customers(crew):
    crew.ann_d.call("post", "/projects", {"name": "Zeta project", "members": []})
    crew.ann_d.call("post", "/meetings", {"title": "Zeta sync", "starts_at": "2030-01-01T08:00:00Z"})
    crew.ann_d.call("post", "/notes", {"title": "Zeta note", "body": {"text": "zzz-hidden-body"}})
    crew.ann_d.call("post", "/customers", {"name": "Zeta Corp", "phone": "02155550000", "email": "hi@zeta.test",
                                           "national_id": "9988776655"})
    got = titles(find(crew.ann_d, "Zeta"))
    assert got == [("crm", "Zeta Corp"), ("meetings", "Zeta sync"), ("notes", "Zeta note"),
                   ("projects", "Zeta project")]
    assert find(crew.bob_d, "Zeta") == []  # not members; the note is owner-only
    assert find(crew.ann_d, "zzz-hidden-body") == []  # note bodies are never searched
    phone = find(crew.ann_d, "5555")
    assert [(r["module"], r["snippet"]) for r in phone] == [("crm", "02155550000")]
    assert [r["module"] for r in find(crew.ann_d, "9988776655")] == ["crm"]
    assert [r["module"] for r in find(crew.ann_d, "hi@zeta")] == ["crm"]


def test_letters_by_title_and_visibility(crew):
    Letter.objects.create(no=1, title="Budget approval", creator=crew.ann, status="draft", visibility="private",
                          publish_mode="now", order="parallel", body={})
    assert [(r["module"], r["title"], r["snippet"]) for r in find(crew.ann_d, "Budget")] == [
        ("letters", "Budget approval", "1")]
    assert find(crew.bob_d, "Budget") == []  # a draft is private to its creator


def test_finance_and_sales_for_holders_only(crew):
    cust = crew.fin_d.call("post", "/customers", {"name": "Omega Trading"}).data
    crew.fin_d.call("post", "/finance/docs", {"kind": "cash", "direction": "receipt", "amount": 7654321,
                                              "date": "2026-05-01", "customer_id": cust["id"],
                                              "description": {"text": "invoice kappa"}})
    crew.fin_d.call("post", "/sales/leads", {"title": "Omega upgrade", "value": 1234500, "probability": 40,
                                             "customer_id": cust["id"]})
    assert {r["module"] for r in find(crew.fin_d, "Omega")} == {"crm", "finance", "sales"}
    assert [r["module"] for r in find(crew.fin_d, "kappa")] == ["finance"]
    assert [r["module"] for r in find(crew.fin_d, "7,654,321")] == ["finance"]
    assert [r["module"] for r in find(crew.fin_d, "1234500")] == ["sales"]
    doc = find(crew.fin_d, "kappa")[0]
    assert doc["title"] == "receipt 7,654,321" and doc["snippet"] == "Omega Trading"
    assert find(crew.ann_d, "Omega") == [] and find(crew.ann_d, "kappa") == []
    assert find(crew.boss, "kappa") == []


def test_file_names_follow_each_subjects_visibility(crew):
    mine = crew.ann_d.call("post", "/tasks", {"title": "With file"}).data
    resp = crew.ann_d.api.client.post(
        f"/api/subjects/{mine['subject_id']}/files",
        {"content_type": "application/pdf", "name": "payroll-march.pdf",
         "file": SimpleUploadedFile("x.pdf", b"%PDF-1.4 test")},
        HTTP_AUTHORIZATION=f"Bearer {crew.ann_d.token}")
    assert resp.status_code == 201, resp.content
    [row] = find(crew.ann_d, "payroll")
    assert (row["module"], row["kind"], row["title"], row["snippet"]) == (
        "files", "file", "payroll-march.pdf", "With file")
    assert find(crew.bob_d, "payroll") == [] and find(crew.boss, "payroll") == []
    assert find(crew.ann_d, "payroll", modules="tasks") == []  # restricted to other modules


def test_chat_conversations_and_messages_only_for_members(crew):
    conv = crew.ann_d.call("post", "/chat/conversations", {"kind": "group", "name": "Launch room",
                                                           "member_ids": [crew.bob.id]}).data
    crew.ann_d.call("post", f"/chat/conversations/{conv['id']}/messages", {"text": "the rocket is ready"})
    got = find(crew.bob_d, "rocket")
    assert [(r["module"], r["kind"], r["title"]) for r in got] == [("chat", "message", "Launch room")]
    assert "rocket" in got[0]["snippet"]
    assert [(r["kind"], r["title"]) for r in find(crew.bob_d, "Launch")] == [("conversation", "Launch room")]
    assert find(crew.out_d, "rocket") == [] and find(crew.out_d, "Launch") == []


def test_modules_filter_and_switched_off_modules(crew, brand_dir):
    crew.ann_d.call("post", "/tasks", {"title": "Sigma task"})
    crew.ann_d.call("post", "/meetings", {"title": "Sigma meeting", "starts_at": "2030-01-01T08:00:00Z"})
    assert {r["module"] for r in find(crew.ann_d, "Sigma")} == {"tasks", "meetings"}
    assert {r["module"] for r in find(crew.ann_d, "Sigma", modules="meetings")} == {"meetings"}
    brand_dir(modules=["tasks"])
    assert {r["module"] for r in find(crew.ann_d, "Sigma")} == {"tasks"}


def test_limit_and_fair_merge(crew):
    for i in range(6):
        crew.ann_d.call("post", "/tasks", {"title": f"Delta task {i}"})
    crew.ann_d.call("post", "/projects", {"name": "Delta project", "members": []})
    rows = find(crew.ann_d, "Delta", limit=4)
    assert len(rows) == 4 and "projects" in {r["module"] for r in rows}  # the project still gets its share
    assert len(find(crew.ann_d, "Delta", limit=20)) == 7


def test_merge_is_stable_and_fills_leftovers():
    a = [{"id": str(i)} for i in range(5)]
    b = [{"id": "b0"}]
    merged = search.merge({"x": a, "y": b}, 4)
    assert [r["id"] for r in merged] == ["0", "1", "2", "b0"]
    assert search.merge({"x": []}, 5) == []


def test_amount_parser():
    assert search.amount_of("۱٬۲۳۴") == 1234 and search.amount_of("12,000") == 12000
    assert search.amount_of("abc") is None


def test_rate_limit_is_60_per_minute(crew):
    for _ in range(60):
        assert crew.ann_d.call("get", "/search?q=zz").status_code == 200
    assert crew.ann_d.call("get", "/search?q=zz").status_code == 429
    assert crew.bob_d.call("get", "/search?q=zz").status_code == 200  # per user


def test_a_failing_module_does_not_break_the_search(crew):
    def boom(user, q, limit):
        raise RuntimeError("broken")

    registry.register(registry.ModuleSpec("broken", None, lambda s: None, lambda u, o, a: False, search=boom))
    try:
        crew.ann_d.call("post", "/tasks", {"title": "Still found"})
        assert [r["module"] for r in find(crew.ann_d, "Still")] == ["tasks"]
    finally:
        registry.unregister("broken")
