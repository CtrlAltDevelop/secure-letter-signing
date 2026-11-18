import base64
import hashlib
import json
import uuid
from datetime import datetime, timezone

import pytest
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature

from accounts.tests.conftest import *  # noqa: F401,F403  (api, make_user, manager, company, PASSWORD)
from core import cryptoutil


def _b64u(n: int) -> str:
    return base64.urlsafe_b64encode(n.to_bytes(32, "big")).rstrip(b"=").decode()


class Device:
    """A test device: real P-256 keys (as the app would make), signs like the app, wraps are opaque blobs."""

    def __init__(self, api, user, name="phone"):
        self.api, self.user, self.name = api, user, name
        self.sign_key, self.enc_key = ec.generate_private_key(ec.SECP256R1()), ec.generate_private_key(ec.SECP256R1())
        self.sign_pub, self.enc_pub = self._jwk(self.sign_key), self._jwk(self.enc_key)
        self.fingerprint = cryptoutil.fingerprint(self.sign_pub, self.enc_pub)
        self.login = api.login(user.email, device=name)
        self.token, self.session_id = self.login["access"], self.login["session_id"]
        self.key_id: str | None = None

    @staticmethod
    def _jwk(priv) -> dict:
        n = priv.public_key().public_numbers()
        return {"kty": "EC", "crv": "P-256", "x": _b64u(n.x), "y": _b64u(n.y)}

    def call(self, method, path, data=None):
        return self.api.call(method, path, data, token=self.token)

    def register_key(self):
        resp = self.call("post", "/keys", {"device_name": self.name, "sign_pub": self.sign_pub,
                                           "enc_pub": self.enc_pub, "fingerprint": self.fingerprint})
        assert resp.status_code == 201, resp.content
        self.key_id = resp.data["id"]
        return resp.data

    def sign(self, payload: dict) -> str:
        der = self.sign_key.sign(cryptoutil.canonical_json(payload).encode(), ec.ECDSA(hashes.SHA256()))
        r, s = decode_dss_signature(der)
        return base64.b64encode(r.to_bytes(32, "big") + s.to_bytes(32, "big")).decode()

    def decision_payload(self, letter: dict, decision="approved", note="") -> dict:
        return {
            "letterId": letter["id"], "title": letter["title"], "decision": decision, "note": note,
            "contentHash": hashlib.sha256(cryptoutil.canonical_json(letter["body"]).encode()).hexdigest(),
            "parentId": letter.get("parent_id"),
            "signer": {"userId": self.user.id, "keyId": self.key_id, "fp": self.fingerprint},
            "sessionId": self.session_id, "deviceName": self.name,
            "signedAt": datetime.now(timezone.utc).isoformat(), "nonce": uuid.uuid4().hex,
        }


@pytest.fixture
def device(api):
    def _make(user, name="phone", *, register=True) -> Device:
        d = Device(api, user, name)
        if register:
            d.register_key()
        return d

    return _make
