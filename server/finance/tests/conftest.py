import pytest

from workspace.tests.conftest import *  # noqa: F401,F403  (api, make_user, manager, login, brand_dir, dummy)


@pytest.fixture(autouse=True)
def _all_modules(brand_dir):
    brand_dir()  # no "modules" key: every module enabled


@pytest.fixture
def team(make_user, login, manager):
    """fin and fin2 hold finance.manage and sales.manage and customer.create; plain holds nothing."""
    team = type("Team", (), {})()
    team.manager, team.boss = manager, login(manager)
    for name, grants in (("fin", ("finance.manage", "sales.manage", "customer.create")),
                         ("fin2", ("finance.manage", "sales.manage", "customer.create")), ("plain", ("customer.create",))):
        user = make_user(f"{name}@corp.test", grants=grants)
        setattr(team, name, user)
        setattr(team, f"{name}_d", login(user))
    return team


@pytest.fixture
def customer(team):
    """A customer file made by fin; plain is a member too, fin2 is not."""
    resp = team.fin_d.call("post", "/customers", {
        "name": "ACME", "members": [{"user_id": team.plain.id, "role": "viewer"}]})
    assert resp.status_code == 201, resp.content
    return resp.data


def doc_body(**over):
    body = {"kind": "cash", "direction": "receipt", "amount": 1_000_000, "date": "2026-05-01"}
    return {**body, **over}
