import pytest

from workspace.tests.conftest import *  # noqa: F401,F403  (api, make_user, manager, login, brand_dir, dummy)


@pytest.fixture(autouse=True)
def _all_modules(brand_dir):
    brand_dir()


@pytest.fixture
def team(make_user, login, manager):
    """ann, bob and cat hold sales.manage; plain does not."""
    team = type("Team", (), {})()
    team.manager, team.boss = manager, login(manager)
    for name, grants in (("ann", ("sales.manage", "customer.create")), ("bob", ("sales.manage",)),
                         ("cat", ("sales.manage",)), ("plain", ("customer.create",))):
        user = make_user(f"{name}@corp.test", grants=grants)
        setattr(team, name, user)
        setattr(team, f"{name}_d", login(user))
    return team


@pytest.fixture
def customer(team):
    """Made by ann; bob and plain are members, cat is not."""
    resp = team.ann_d.call("post", "/customers", {"name": "ACME", "members": [
        {"user_id": team.bob.id, "role": "member"}, {"user_id": team.plain.id, "role": "viewer"}]})
    assert resp.status_code == 201, resp.content
    return resp.data


def lead_body(**over):
    return {"title": "Big deal", "value": 1000, "probability": 50, **over}
