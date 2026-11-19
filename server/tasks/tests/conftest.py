import pytest
from workspace.tests.conftest import *  # noqa: F401,F403  (api, make_user, manager, login, brand_dir, dummy)


@pytest.fixture
def team(make_user, login, manager):
    """cat creates; olga owns; abe and ben approve in that order; fay follows; out is not involved."""
    grants = ("task.create",)
    users = {n: make_user(f"{n}@corp.test", grants=grants) for n in ("cat", "olga", "abe", "ben", "fay", "out")}
    team = type("Team", (), {})()
    team.manager = manager
    team.boss = login(manager)
    for name, user in users.items():
        setattr(team, name, user)
        setattr(team, f"{name}_d", login(user))
    return team


@pytest.fixture
def make_task(team):
    def make(**over):
        body = {"title": "Quarterly report", "owner_ids": [team.olga.id], **over}
        resp = team.cat_d.call("post", "/tasks", body)
        assert resp.status_code == 201, resp.content
        return resp.data

    return make


@pytest.fixture
def approved_flow(team, make_task):
    return make_task(approver_ids=[team.abe.id, team.ben.id], follower_ids=[team.fay.id])
