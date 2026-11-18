import pytest
from django.test import Client

from accounts.admin import UserEditForm
from accounts.models import User

from .conftest import PASSWORD


@pytest.fixture
def root(db) -> User:
    return User.objects.create_superuser("root@corp.test", PASSWORD)


def test_admin_is_reachable_by_superuser_only(root, make_user, manager):
    boss = Client()
    boss.force_login(manager)
    assert boss.get("/admin/").status_code == 302  # manager is not staff: redirected to login
    dev = Client()
    dev.force_login(root)
    assert dev.get("/admin/").status_code == 200
    assert dev.get("/admin/accounts/user/").status_code == 200


def test_admin_has_no_letter_models_and_no_delete(root):
    dev = Client()
    dev.force_login(root)
    body = dev.get("/admin/").content.decode().lower()
    assert "letter" not in body.replace("letter signing", "")
    assert dev.get(f"/admin/accounts/user/{root.pk}/delete/").status_code == 403


def test_second_manager_is_refused_by_the_admin_form(manager, make_user):
    other = make_user("b@corp.test")
    data = {"email": other.email, "is_manager": True, "password": other.password, "is_active": True,
            "date_joined": "2026-01-01 00:00:00", "email_verified": False}
    form = UserEditForm(data, instance=other)
    assert not form.is_valid()
    assert "already the manager" in str(form.errors)


def test_superuser_can_issue_an_invite_code_but_not_delete_it(root):
    from accounts.models import InviteCode

    dev = Client()
    dev.force_login(root)
    assert dev.get("/admin/accounts/invitecode/add/").status_code == 200
    resp = dev.post("/admin/accounts/invitecode/add/", {"max_uses": 3, "active": "on"})
    assert resp.status_code == 302
    code = InviteCode.objects.get()
    assert code.created_by == root and code.max_uses == 3 and code.code
    assert dev.get(f"/admin/accounts/invitecode/{code.pk}/delete/").status_code == 403
