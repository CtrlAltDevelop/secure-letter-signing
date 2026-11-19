import pytest
from django.contrib.auth.hashers import make_password

from workspace.tests.conftest import *  # noqa: F401,F403  (api, make_user, manager, login, brand_dir, dummy)

PIN = "123456"


@pytest.fixture(autouse=True)
def _all_modules(brand_dir):
    brand_dir()  # no "modules" key: every module enabled


@pytest.fixture
def team(make_user, login, manager):
    """cat chairs, sue is secretary, mia and max are members, out is not involved. All may create tasks."""
    team = type("Team", (), {})()
    team.manager, team.boss = manager, login(manager)
    for name in ("cat", "sue", "mia", "max", "out"):
        user = make_user(f"{name}@corp.test", grants=("task.create", "project.create"))
        user.signing_pin_hash = make_password(PIN)
        user.save(update_fields=["signing_pin_hash"])
        setattr(team, name, user)
        setattr(team, f"{name}_d", login(user))
    return team


@pytest.fixture
def org_body(team):
    return {"title": "Board", "kind": "organizational", "starts_at": "2030-01-01T08:00:00Z",
            "attendees": [{"user_id": team.cat.id, "role": "chair"}, {"user_id": team.sue.id, "role": "secretary"},
                          {"user_id": team.mia.id, "role": "member"}, {"user_id": team.max.id, "role": "member"}]}


@pytest.fixture
def meeting(team, org_body):
    resp = team.cat_d.call("post", "/meetings", org_body)
    assert resp.status_code == 201, resp.content
    return resp.data


@pytest.fixture
def held(team, meeting):
    """A held organizational meeting with mia and cat present."""
    mid = meeting["id"]
    for user in (team.mia, team.cat):
        assert team.sue_d.call("post", f"/meetings/{mid}/attendance",
                               {"user_id": user.id, "attendance": "present"}).status_code == 200
    assert team.cat_d.call("post", f"/meetings/{mid}/hold").status_code == 200
    return meeting
