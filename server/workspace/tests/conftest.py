from types import SimpleNamespace

import json

import pytest
from channels.testing import WebsocketCommunicator

from accounts.tests.conftest import *  # noqa: F401,F403  (api, make_user, manager, company, PASSWORD)
from accounts.tests.conftest import PASSWORD
from config.asgi import application
from workspace import registry
from workspace.models import Subject


@pytest.fixture
def brand_dir(tmp_path, settings):
    """Point the server at a temporary brand.json; `brand_dir(modules=[...])` rewrites it."""

    def write(**extra):
        (tmp_path / "t").mkdir(exist_ok=True)
        data = {"id": "t", "name": "T", "colors": {}, **extra}
        (tmp_path / "t" / "brand.json").write_text(json.dumps(data), encoding="utf-8")
        settings.BRANDS_DIR, settings.BRAND = tmp_path, "t"

    return write


@pytest.fixture
def dummy(db, brand_dir):
    """A registered module `dummy`: members see things, editors may also label. `dummy.add(subject, see=, edit=)`."""
    brand_dir()  # no "modules" key: every module enabled
    table: dict = {}

    def resolve(subject):
        return table.get(subject.id)

    def can(user, obj, action):
        if action == "see":
            return user.id in obj.see or user.id in obj.edit
        return user.id in obj.edit

    registry.register(registry.ModuleSpec("dummy", None, resolve, can))

    def add(*, see=(), edit=()):
        subject = Subject.objects.create(module="dummy", kind="thing")
        table[subject.id] = SimpleNamespace(see={u.id for u in see}, edit={u.id for u in edit})
        return subject

    yield SimpleNamespace(add=add)
    registry.unregister("dummy")


class Login:
    def __init__(self, api, user):
        self.api, self.user = api, user
        data = api.login(user.email)
        self.token = data["access"]

    def call(self, method, path, data=None):
        return self.api.call(method, path, data, token=self.token)


@pytest.fixture
def login(api):
    return lambda user: Login(api, user)


def connect(token: str) -> WebsocketCommunicator:
    return WebsocketCommunicator(application, f"/ws/?token={token}", headers=[(b"origin", b"http://localhost")])
