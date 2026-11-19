import pytest
from django.utils import timezone

from projects.tests.conftest import *  # noqa: F401,F403  (crew, project, make_ptask, make_user, login, manager)


@pytest.fixture(autouse=True)
def _all_modules(brand_dir):
    brand_dir()


@pytest.fixture
def watcher(make_user, login):
    """Holds monitor.view only."""
    user = make_user("watch@corp.test", grants=("monitor.view",))
    return login(user)


@pytest.fixture
def overdue_task(crew, make_ptask):
    from tasks.models import Task

    data = make_ptask()
    Task.objects.filter(pk=data["id"]).update(due_at=timezone.now() - timezone.timedelta(days=3))
    return data
