import json
import base64

import pytest
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
from django.db import connection, transaction

from accounts.models import verify_audit_chain
from core import cryptoutil
from letters.models import Letter, Signature
from letters.tests.conftest import BODY


def test_body_is_encrypted_at_rest_and_round_trips_through_the_api(world):
    lid = world.create()["id"]
    stored = Letter.objects.get(pk=lid).body
    assert set(stored) == {"v", "ct"} and stored["v"] == 3
    with connection.cursor() as cur:  # the raw column, not the ORM
        cur.execute("SELECT body FROM letters_letter WHERE id = %s", [lid.replace("-", "")])
        raw = cur.fetchone()[0]
    assert "Dear all" not in raw and "budget" not in raw
    assert world.alice_d.call("get", f"/letters/{lid}").data["body"] == BODY
    assert world.dev(world.signers[0]).call("get", f"/letters/{lid}").data["body"] == BODY


def test_attachment_bytes_are_encrypted_on_disk_and_round_trip(world, settings, tmp_path):
    from django.core.files.uploadedfile import SimpleUploadedFile

    from letters.models import Attachment

    settings.MEDIA_ROOT = tmp_path
    lid = world.create(send=False)["id"]
    d = world.alice_d
    secret = b"%PDF-1.4 top secret salary table"
    up = d.api.client.post(f"/api/letters/{lid}/attachments", {
        "content_type": "application/pdf", "label": "pay", "file": SimpleUploadedFile("x.pdf", secret)},
        HTTP_AUTHORIZATION=f"Bearer {d.token}")
    assert up.status_code == 201
    att = Attachment.objects.get(pk=up.json()["id"])
    with att.file.open("rb") as handle:
        on_disk = handle.read()
    assert secret not in on_disk and on_disk != secret
    assert cryptoutil.decrypt_bytes(on_disk) == secret
    got = d.api.client.get(f"/api/letters/{lid}/attachments/{up.json()['id']}", HTTP_AUTHORIZATION=f"Bearer {d.token}")
    assert got.content == secret


def test_seal_key_is_published_and_every_seal_verifies_with_it(world):
    lid = world.create()["id"]
    world.sign(world.signers[0], lid)
    info = world.dev(world.viewer).call("get", "/letters/seal-key").data
    assert info["alg"] == "Ed25519" and info["fingerprint"].count("-") == 7
    sig = world.alice_d.call("get", f"/letters/{lid}").data["signatures"][0]
    public = Ed25519PublicKey.from_public_bytes(base64.b64decode(info["public_key"]))
    public.verify(base64.b64decode(sig["seal"]), cryptoutil.canonical_json(sig["payload"]).encode())
    payload = sig["payload"]
    assert payload["v"] == 3 and payload["method"] == "pin" and payload["deviceName"] == "phone"
    assert payload["signer"]["email"] == world.signers[0].email and len(payload["nonce"]) >= 16
    assert payload["contentHash"] == cryptoutil.content_hash(BODY)
    assert sig["method"] == "pin" and sig["device_name"] == "phone" and sig["signed_at"] == payload["signedAt"]
    tampered = {**payload, "decision": "rejected"}
    with pytest.raises(InvalidSignature):
        public.verify(base64.b64decode(sig["seal"]), cryptoutil.canonical_json(tampered).encode())


def test_certificate_detects_a_tampered_payload_and_a_tampered_body(world):
    lid = world.create()["id"]
    world.sign(world.signers[0], lid)
    cert = world.alice_d.call("get", f"/letters/{lid}/certificate").data
    assert cert["all_verified"] and cert["seal_key"]["alg"] == "Ed25519"
    assert cert["letter"]["content_hash"] == cryptoutil.content_hash(BODY)
    sig = Signature.objects.get()
    with connection.cursor() as cur:  # simulate a DBA attack: drop the immutability trigger first
        cur.execute("DROP TRIGGER no_update_letters_signature")
        cur.execute("UPDATE letters_signature SET decision='rejected', payload=%s WHERE id=%s",
                    [json.dumps({**sig.payload, "decision": "rejected"}), sig.id])
    assert world.alice_d.call("get", f"/letters/{lid}/certificate").data["all_verified"] is False


def test_certificate_fails_when_the_body_no_longer_matches_the_signed_hash(world):
    lid = world.create()["id"]
    world.sign(world.signers[0], lid)
    other = cryptoutil.encrypt_body({"text": "something else"})
    with connection.cursor() as cur:
        cur.execute("DROP TRIGGER sent_letter_is_immutable")
        cur.execute("UPDATE letters_letter SET body=%s WHERE id=%s",
                    [json.dumps(other), lid.replace("-", "")])
    cert = world.alice_d.call("get", f"/letters/{lid}/certificate").data
    assert cert["signatures"][0]["verified"] is False


def test_signatures_are_immutable_and_cannot_be_deleted(world):
    lid = world.create()["id"]
    world.sign(world.signers[0], lid)
    with pytest.raises(Exception, match="not allowed"), transaction.atomic():
        Signature.objects.update(decision="rejected")
    with pytest.raises(Exception, match="not allowed"), transaction.atomic():
        Signature.objects.all().delete()


def test_a_wrong_data_key_reports_an_error_instead_of_garbage(world, settings):
    lid = world.create()["id"]
    settings.DATA_KEY = "a-completely-different-key"
    assert world.alice_d.call("get", f"/letters/{lid}").status_code == 500


def test_audit_records_signing_actions_and_chain_verifies(world):
    from accounts.models import AuditEvent

    lid = world.create()["id"]
    world.sign(world.signers[0], lid, pin="000000")
    world.sign(world.signers[0], lid)
    actions = list(AuditEvent.objects.values_list("action", flat=True))
    assert "sign_pin_failed" in actions and "letter_signed" in actions
    signed = AuditEvent.objects.get(action="letter_signed")
    assert signed.data["method"] == "pin" and signed.data["decision"] == "approved"
    assert verify_audit_chain() is None
