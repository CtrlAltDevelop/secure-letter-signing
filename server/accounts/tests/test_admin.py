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


def test_company_settings_is_a_single_row_create_then_edit(root):
    from accounts.models import CompanySettings
    dev = Client()
    dev.force_login(root)
    url = "/admin/accounts/companysettings/"
    assert dev.get(url).headers["Location"].endswith("/add/")
    resp = dev.post(url + "add/", {"lh_name": "Acme", "lh_phone": "1", "smtp_port": 587, "smtp_use_tls": "on"})
    assert resp.status_code == 302, getattr(resp, "context", None) and resp.context["adminform"].form.errors
    assert CompanySettings.objects.get().letterhead == {"name": "Acme", "phone": "1"}
    assert dev.get(url).headers["Location"].endswith("/1/change/")
    assert dev.get(url + "add/").status_code == 403
    png = b"\x89PNG\r\n" + b"0" * 20
    from django.core.files.uploadedfile import SimpleUploadedFile
    dev.post(url + "1/change/", {"lh_name": "Acme", "smtp_port": 587, "lh_logo": SimpleUploadedFile("l.png", png)})
    assert CompanySettings.objects.get().letterhead["logo"].startswith("data:image/png;base64,")
    bad = dev.post(url + "1/change/", {"smtp_port": 587, "lh_logo": SimpleUploadedFile("l.png", b"not an image")})
    assert bad.status_code == 200


def test_import_users_csv_creates_skips_and_reports_invalid(root, make_user):
    from accounts.admin import import_users_from_csv
    make_user("old@corp.test")
    rep = import_users_from_csv("email,full_name\\nnew@corp.test,Nia\\nold@corp.test,X\\nbad,Y\\n".replace("\\n", "\n"))
    assert rep["created"] == ["new@corp.test"] and rep["skipped"] == ["old@corp.test"] and len(rep["invalid"]) == 1
    u = User.objects.get(email="new@corp.test")
    assert u.full_name == "Nia" and not u.has_usable_password()
    dev = Client()
    dev.force_login(root)
    assert dev.get("/admin/accounts/user/import-users/").status_code == 200
