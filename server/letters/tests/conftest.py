import pytest
from django.contrib.auth.hashers import make_password

from accounts.tests.conftest import *  # noqa: F401,F403  (api, make_user, manager, company, PASSWORD)
from accounts.tests.conftest import PASSWORD

PIN = "123456"
BODY = {"text": "Dear all, the budget for 2027 is attached.", "attachments": []}


class Dev:
    """A signed-in session of a user (one device)."""

    def __init__(self, api, user, name="phone", *, biometric=False):
        self.api, self.user, self.name, self.biometric = api, user, name, biometric
        resp = api.call("post", "/auth/login", {"email": user.email, "password": PASSWORD, "device_name": name})
        assert resp.status_code == 200, resp.content
        self.token, self.session_id = resp.data["access"], resp.data["session_id"]
        if biometric:  # enrolment: needs the user's signing PIN
            if not user.signing_pin_hash:
                user.signing_pin_hash = make_password(PIN)
                user.save(update_fields=["signing_pin_hash"])
            enrol = self.call("patch", "/me/sessions/current", {"biometric": True, "pin": PIN})
            assert enrol.status_code == 200, enrol.content

    def call(self, method, path, data=None):
        return self.api.call(method, path, data, token=self.token)


@pytest.fixture
def dev(api):
    def _make(user, name="phone", *, biometric=False) -> Dev:
        return Dev(api, user, name, biometric=biometric)

    return _make


class World:
    def __init__(self, make_user, dev, manager):
        self.alice = make_user("alice@corp.test", grants=("letter.create", "letter.see"))
        self.signers = [make_user(f"s{i}@corp.test", grants=("letter.sign",)) for i in range(3)]
        self.viewer = make_user("viewer@corp.test", grants=("letter.see",))
        self.outsider = make_user("out@corp.test", grants=("letter.see",))
        self.boss_user = manager
        users = [self.alice, *self.signers, self.viewer, self.outsider, manager]
        for u in users:  # everyone has a signing PIN (set directly; the API path has its own tests)
            u.signing_pin_hash = make_password(PIN)
            u.save(update_fields=["signing_pin_hash"])
        self.d = {u.email: dev(u) for u in users}
        self.boss = self.d[manager.email]

    @property
    def alice_d(self):
        return self.d[self.alice.email]

    def dev(self, user):
        return self.d[user.email]

    def body(self, *, visibility="public", signers=None, viewers=(), order="parallel", mode="after_sign", parent=None):
        signers = signers or self.signers
        return {"title": "Budget 2027", "body": BODY, "visibility": visibility, "publish_mode": mode, "order": order,
                "signer_ids": [s.id for s in signers], "viewer_ids": [v.id for v in viewers], "parent_id": parent}

    def create(self, send=True, **kw):
        resp = self.alice_d.call("post", "/letters", self.body(**kw))
        assert resp.status_code == 201, resp.content
        if send:
            sent = self.alice_d.call("post", f"/letters/{resp.data['id']}/send")
            assert sent.status_code == 200, sent.content
            return sent.data
        return resp.data

    def sign(self, user, letter_id, decision="approved", note="", pin=PIN):
        return self.dev(user).call("post", f"/letters/{letter_id}/sign", {"decision": decision, "note": note, "pin": pin})


@pytest.fixture
def world(make_user, dev, manager):
    return World(make_user, dev, manager)
