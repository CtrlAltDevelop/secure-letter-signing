import pytest
from tasks.tests.conftest import *  # noqa: F401,F403  (api, make_user, manager, login, brand_dir, dummy, team, make_task)


@pytest.fixture
def crew(make_user, login, manager):
    """pam owns the project (manager role), mia is a member, vic a viewer, mel a second member, out is not in it."""
    grants = ("task.create", "project.create")
    users = {n: make_user(f"{n}@corp.test", grants=grants) for n in ("pam", "mia", "vic", "mel", "out")}
    crew = type("Crew", (), {})()
    crew.manager = manager
    crew.boss = login(manager)
    for name, user in users.items():
        setattr(crew, name, user)
        setattr(crew, f"{name}_d", login(user))
    return crew


@pytest.fixture
def project(crew):
    body = {"name": "Website", "description": {"text": "private plan"}, "members": [
        {"user_id": crew.mia.id, "role": "member"}, {"user_id": crew.vic.id, "role": "viewer"},
        {"user_id": crew.mel.id, "role": "member"}]}
    resp = crew.pam_d.call("post", "/projects", body)
    assert resp.status_code == 201, resp.content
    return resp.data


@pytest.fixture
def make_ptask(crew, project):
    def make(who=None, **over):
        body = {"title": "Build page", "project_id": project["id"], "owner_ids": [crew.mia.id], **over}
        resp = (who or crew.mia_d).call("post", "/tasks", body)
        assert resp.status_code == 201, resp.content
        return resp.data

    return make


def column_id(project, kind):
    return next(c["id"] for c in project["columns"] if c["kind"] == kind)
