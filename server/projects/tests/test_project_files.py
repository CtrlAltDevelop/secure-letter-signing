from datetime import timedelta

from django.core.files.uploadedfile import SimpleUploadedFile
from django.utils import timezone

from tasks.models import Task
from workspace.models import File

PDF = b"%PDF-1.4 test"


def upload(who, subject_id, name, ctype="application/pdf"):
    resp = who.api.client.post(
        f"/api/subjects/{subject_id}/files",
        {"content_type": ctype, "name": name, "file": SimpleUploadedFile("x", PDF)},
        HTTP_AUTHORIZATION=f"Bearer {who.token}")
    assert resp.status_code == 201, resp.content
    return resp.json()


def raw_file(subject_id, user, name, ctype, age_days=0):
    return File.objects.create(subject_id=subject_id, uploaded_by=user, name=name, content_type=ctype, size=10,
                               sha256_plain="0" * 64, blob="workspace/none",
                               created_at=timezone.now() - timedelta(days=age_days))


def url(project, query=""):
    return f"/projects/{project['id']}/files{query}"


def test_lists_task_and_project_files_newest_first(crew, project, make_ptask):
    t1, t2 = make_ptask(title="One"), make_ptask(title="Two")
    upload(crew.mia_d, t1["subject_id"], "a.pdf")
    upload(crew.mia_d, t2["subject_id"], "b.pdf")
    upload(crew.pam_d, project["subject_id"], "plan.pdf")
    rows = crew.vic_d.call("get", url(project)).data
    assert [r["name"] for r in rows] == ["plan.pdf", "b.pdf", "a.pdf"]
    first, second = rows[0], rows[1]
    assert first["task_id"] is None and first["task_title"] is None
    assert second["task_id"] == t2["id"] and second["task_title"] == "Two"
    assert set(second) == {"id", "name", "content_type", "size", "task_id", "task_title", "uploaded_by", "created_at"}
    assert second["uploaded_by"]["id"] == crew.mia.id and second["size"] == len(PDF)


def test_type_filter_name_search_and_paging(crew, project, make_ptask):
    task = make_ptask()
    sid = task["subject_id"]
    raw_file(sid, crew.mia, "photo.png", "image/png", 4)
    raw_file(sid, crew.mia, "clip.mp4", "video/mp4", 3)
    raw_file(sid, crew.mia, "sheet.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", 2)
    raw_file(sid, crew.mia, "notes.txt", "text/plain", 1)
    raw_file(sid, crew.mia, "Report.pdf", "application/pdf", 0)
    names = lambda q: [r["name"] for r in crew.mia_d.call("get", url(project, q)).data]  # noqa: E731
    assert names("?type=image") == ["photo.png"]
    assert names("?type=video") == ["clip.mp4"]
    assert names("?type=document") == ["Report.pdf", "notes.txt", "sheet.xlsx"]
    assert names("?q=report") == ["Report.pdf"]
    assert names("?type=document&q=sheet") == ["sheet.xlsx"]
    assert names("?limit=2") == ["Report.pdf", "notes.txt"]
    assert names("?limit=2&offset=4") == ["photo.png"]
    assert crew.mia_d.call("get", url(project, "?type=audio")).status_code == 422


def test_inactive_files_and_other_projects_are_left_out(crew, project, make_ptask):
    task = make_ptask()
    gone = upload(crew.mia_d, task["subject_id"], "gone.pdf")
    upload(crew.mia_d, task["subject_id"], "kept.pdf")
    crew.mia_d.call("delete", f"/files/{gone['id']}")
    other = crew.pam_d.call("post", "/projects", {"name": "Other"}).data
    other_task = crew.pam_d.call("post", "/tasks", {"title": "t", "project_id": other["id"]}).data
    upload(crew.pam_d, other_task["subject_id"], "elsewhere.pdf")
    assert [r["name"] for r in crew.mia_d.call("get", url(project)).data] == ["kept.pdf"]


def test_permissions_members_only(crew, project, make_ptask):
    task = make_ptask()
    upload(crew.mia_d, task["subject_id"], "a.pdf")
    expected = {"pam_d": 200, "mia_d": 200, "vic_d": 200, "mel_d": 200, "out_d": 404, "boss": 404}
    for name, code in expected.items():
        assert getattr(crew, name).call("get", url(project)).status_code == code, name


def test_files_of_removed_tasks_are_for_managers_only(crew, project, make_ptask):
    task = make_ptask()
    upload(crew.mia_d, task["subject_id"], "secret.pdf")
    Task.objects.filter(pk=task["id"]).update(hidden=True)
    assert crew.mia_d.call("get", url(project)).data == []
    assert [r["name"] for r in crew.pam_d.call("get", url(project)).data] == ["secret.pdf"]
