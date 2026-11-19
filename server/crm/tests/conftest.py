import pytest

from workspace.tests.conftest import *  # noqa: F401,F403  (api, make_user, manager, login, brand_dir, dummy)


@pytest.fixture(autouse=True)
def _all_modules(brand_dir):
    brand_dir()  # no "modules" key: every module enabled


@pytest.fixture
def team(make_user, login, manager):
    """ann creates files; bob is a member and vic a viewer in `file`; out is not on any file."""
    team = type("Team", (), {})()
    team.manager, team.boss = manager, login(manager)
    for name in ("ann", "bob", "vic", "out"):
        user = make_user(f"{name}@corp.test", grants=("task.create", "customer.create"))
        setattr(team, name, user)
        setattr(team, f"{name}_d", login(user))
    return team


@pytest.fixture
def file(team):
    """A customer file made by ann with bob (member) and vic (viewer)."""
    resp = team.ann_d.call("post", "/customers", {
        "name": "ACME", "kind": "company", "phone": "021111", "email": "Info@Acme.test", "national_id": "1010",
        "address": {"text": "Secret street 1"}, "notes": {"text": "Secret notes"},
        "members": [{"user_id": team.bob.id, "role": "member"}, {"user_id": team.vic.id, "role": "viewer"}]})
    assert resp.status_code == 201, resp.content
    return resp.data
