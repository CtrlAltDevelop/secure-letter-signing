import json

import pytest
from django.test import Client

from accounts.models import BASE_PERMISSION, CompanySettings, Permission, User

PASSWORD = "Str0ng-Passw0rd!x"


class Api:
    def __init__(self) -> None:
        self.client = Client()

    def call(self, method: str, path: str, data=None, token: str | None = None):
        headers = {"HTTP_AUTHORIZATION": f"Bearer {token}"} if token else {}
        body = json.dumps(data) if data is not None else None
        resp = getattr(self.client, method)(f"/api{path}", body, content_type="application/json", **headers)
        resp.data = resp.json() if resp.content else None
        return resp

    def login(self, email: str, password: str = PASSWORD, device: str = "test-phone"):
        resp = self.call("post", "/auth/login", {"email": email, "password": password, "device_name": device})
        assert resp.status_code == 200, resp.content
        return resp.data


@pytest.fixture
def api() -> Api:
    return Api()


@pytest.fixture
def make_user(db):
    def _make(email: str, *, manager: bool = False, grants: tuple[str, ...] = (), active: bool = True) -> User:
        user = User.objects.create_user(email, PASSWORD, is_active=active, is_manager=manager)
        user.grants.add(*Permission.objects.filter(code__in=(BASE_PERMISSION, *grants)))
        return user

    return _make


@pytest.fixture
def manager(make_user) -> User:
    return make_user("boss@corp.test", manager=True)


@pytest.fixture
def company(db) -> CompanySettings:
    return CompanySettings.load()
