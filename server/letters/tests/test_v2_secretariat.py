"""Letters v2: secretariat numbers, register entries, files and customer links."""
import uuid
from datetime import datetime, timezone

import pytest

from letters import numbering
from letters.models import NumberSequence, SecretariatEntry
from letters.tests.conftest import *  # noqa: F401,F403  (world, dev, PIN)
from letters.tests.test_v2_boxes import ids, publish


@pytest.fixture
def clerk(world, make_user, dev):
    user = make_user("clerk@corp.test", grants=("letter.secretariat", "letter.see"))
    world.d[user.email] = dev(user)
    return world.d[user.email]


def at(monkeypatch, year, month, day):
    monkeypatch.setattr(numbering, "_now", lambda: datetime(year, month, day, 12, tzinfo=timezone.utc))


def register(dev, **over):
    return dev.call("post", "/secretariat/entries", {"direction": "in", "title": "Offer from ACME", **over})


def test_permission_is_seeded_and_not_granted_to_everyone(world, clerk):
    from accounts.models import Permission

    assert Permission.objects.filter(code="letter.secretariat").exists()
    assert register(world.alice_d).status_code == 403
    assert world.alice_d.call("get", "/secretariat/entries").status_code == 403
    assert register(clerk).status_code == 201
    granted = world.boss.call("put", f"/manage/users/{world.alice.id}/permissions",
                              {"codes": ["letter.create", "letter.see", "letter.secretariat"]})
    assert granted.status_code == 200, granted.content
    assert register(world.alice_d).status_code == 201


def test_incoming_numbers_use_the_jalali_year_and_roll_over(world, clerk, monkeypatch):
    at(monkeypatch, 2026, 3, 25)  # 1405-01-05
    first = register(clerk, party_name="ACME", party_ref="INV-7", summary="three pages").data
    second = register(clerk).data
    assert (first["number"], second["number"]) == ("1405/0001", "1405/0002")
    assert first["jalali_year"] == 1405 and first["seq"] == 1 and first["direction"] == "in"
    assert first["summary"]["text"] == "three pages" and first["party_name"] == "ACME"
    at(monkeypatch, 2026, 3, 19)  # 1404-12-28: the previous year keeps its own sequence
    assert register(clerk).data["number"] == "1404/0001"
    at(monkeypatch, 2027, 3, 21)  # 1406-01-01
    assert register(clerk).data["number"] == "1406/0001"
    assert register(clerk, direction="out").data["number"] == "1406/0001"  # out has its own sequence


def test_numbers_are_unique_under_repeated_calls(world, clerk):
    numbers = [register(clerk).data["number"] for _ in range(15)]
    assert len(set(numbers)) == 15
    assert NumberSequence.objects.get(kind="in").last == 15
    assert numbering.format_number(1405, 12) == "1405/0012"


def test_failed_registration_gives_the_number_back(world, clerk):
    assert register(clerk, title="").status_code == 422  # title required
    assert register(clerk, letter_id=str(uuid.uuid4()), direction="in").status_code == 422
    assert register(clerk).data["seq"] == 1


def test_outgoing_number_for_a_published_letter_once(world, clerk):
    pending = world.create(visibility="public", mode="now")
    assert register(clerk, direction="out", letter_id=pending["id"]).status_code == 409  # not published yet
    letter = publish(world, visibility="public")
    resp = register(clerk, direction="out", title="", letter_id=letter["id"])
    assert resp.status_code == 201, resp.content
    assert resp.data["letter_id"] == letter["id"] and resp.data["title"] == "Budget 2027"
    assert register(clerk, direction="out", letter_id=letter["id"]).status_code == 409  # one number per letter
    assert NumberSequence.objects.get(kind="out").last == 1  # the refused request did not burn a number
    brief = world.alice_d.call("get", f"/letters/{letter['id']}").data
    assert brief["number_label"] == resp.data["number"]
    assert world.alice_d.call("get", "/letters").data[0]["number_label"] == resp.data["number"]
    assert ids(world.alice_d.call("get", f"/letters/search?number={resp.data['number']}")) == [letter["id"]]


def test_outgoing_number_needs_a_letter_the_clerk_can_see(world, clerk):
    private = publish(world, visibility="private")
    assert register(clerk, direction="out", letter_id=private["id"]).status_code == 404


def test_list_filters_and_scope(world, clerk, monkeypatch):
    at(monkeypatch, 2026, 3, 25)
    register(clerk, title="Offer from ACME", party_name="ACME Co")
    register(clerk, direction="out", title="Reply to bank", party_name="Bank Melli")
    at(monkeypatch, 2027, 3, 25)
    register(clerk, title="Invoice")
    listed = clerk.call("get", "/secretariat/entries").data
    assert [e["title"] for e in listed] == ["Invoice", "Reply to bank", "Offer from ACME"]
    assert [e["title"] for e in clerk.call("get", "/secretariat/entries?direction=out").data] == ["Reply to bank"]
    assert [e["title"] for e in clerk.call("get", "/secretariat/entries?year=1405").data] == ["Reply to bank", "Offer from ACME"]
    assert [e["title"] for e in clerk.call("get", "/secretariat/entries?q=melli").data] == ["Reply to bank"]
    assert len(clerk.call("get", "/secretariat/entries?limit=1&offset=1").data) == 1


def test_patch_updates_allowed_fields_with_history(world, clerk):
    entry = register(clerk, party_name="ACME").data
    resp = clerk.call("patch", f"/secretariat/entries/{entry['id']}",
                      {"title": "Offer v2", "summary": "new text", "number": "9999/0001"})
    assert resp.status_code == 200, resp.content
    assert resp.data["title"] == "Offer v2" and resp.data["summary"]["text"] == "new text"
    assert resp.data["number"] == entry["number"]  # the number never changes
    hist = clerk.call("get", f"/subjects/{entry['subject_id']}/history").data
    fields = {h["field"]: h for h in hist}
    assert fields["title"]["old"] == "Offer from ACME" and fields["title"]["new"] == "Offer v2"
    assert fields["summary"]["new"] == {"changed": True}
    assert world.alice_d.call("patch", f"/secretariat/entries/{entry['id']}", {"title": "x"}).status_code == 403


def test_entry_files_use_the_workspace_endpoints(world, clerk):
    entry = register(clerk).data
    sid = entry["subject_id"]
    up = clerk.api.client.post(f"/api/subjects/{sid}/files", {"content_type": "application/pdf", "name": "scan.pdf",
                                                              "file": _upload()},
                               HTTP_AUTHORIZATION=f"Bearer {clerk.token}")
    assert up.status_code == 201, up.content
    assert len(clerk.call("get", f"/subjects/{sid}/files").data) == 1
    assert world.alice_d.call("get", f"/subjects/{sid}/files").status_code == 404  # not the secretariat's business
    assert world.alice_d.call("get", f"/subjects/{sid}/comments").status_code == 404


def _upload():
    from django.core.files.uploadedfile import SimpleUploadedFile

    return SimpleUploadedFile("scan.pdf", b"%PDF-1.4 test", content_type="application/pdf")


def make_customer(*members):
    from crm import service
    from crm.models import CustomerMember

    customer = service.new_customer(members[0], {"name": "ACME"})
    for user in members[1:]:
        CustomerMember.objects.create(customer=customer, user=user, role="member")
    return str(customer.id)


def test_customer_links(world, clerk):
    a, b = make_customer(clerk.user, world.alice), make_customer(clerk.user)
    assert clerk.call("put", f"/secretariat/entries/{register(clerk).data['id']}/customers",
                      {"customer_refs": [str(uuid.uuid4())]}).status_code == 422
    entry = register(clerk).data
    resp = clerk.call("put", f"/secretariat/entries/{entry['id']}/customers", {"customer_refs": [a, b]})
    assert resp.status_code == 200 and sorted(resp.data["customer_refs"]) == sorted([a, b])
    resp = clerk.call("put", f"/secretariat/entries/{entry['id']}/customers", {"customer_refs": [b]})
    assert resp.data["customer_refs"] == [b]
    assert clerk.call("get", f"/secretariat/entries/{entry['id']}").data["customer_refs"] == [b]
    assert world.alice_d.call("put", f"/secretariat/entries/{entry['id']}/customers",
                              {"customer_refs": [a]}).status_code == 403
    letter = world.create(visibility="public", mode="now")
    lid = letter["id"]
    assert world.alice_d.call("put", f"/letters/{lid}/customers", {"customer_refs": [a]}).status_code == 200
    assert world.alice_d.call("get", f"/letters/{lid}").data["customer_refs"] == [a]
    assert world.dev(world.viewer).call("put", f"/letters/{lid}/customers", {"customer_refs": [a]}).status_code == 403
    assert clerk.call("put", f"/letters/{lid}/customers", {"customer_refs": [a, b]}).status_code == 200
    assert world.dev(world.outsider).call("put", f"/letters/{world.create(visibility='private')['id']}/customers",
                                          {"customer_refs": [a]}).status_code == 404


def test_registration_audit_has_no_titles(world, clerk):
    from accounts.models import AuditEvent

    register(clerk, title="Very private title", party_name="Secret Party")
    row = AuditEvent.objects.get(action="secretariat_registered")
    assert "private" not in str(row.data) + row.target and "Secret" not in str(row.data)
    assert SecretariatEntry.objects.count() == 1
