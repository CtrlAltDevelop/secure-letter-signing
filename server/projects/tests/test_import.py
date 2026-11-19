import io
import json
import zipfile

from django.core.files.uploadedfile import SimpleUploadedFile

from accounts.models import AuditEvent
from projects.models import BoardColumn
from tasks.models import Task, TaskPerson
from workspace.models import Label, SubjectLabel

HEADER = "title,description,due,column,owner_email,priority,checklist\n"


def push(who, project, fmt, data: bytes, name="data"):
    resp = who.api.client.post(
        f"/api/projects/{project['id']}/import", {"format": fmt, "file": SimpleUploadedFile(name, data)},
        HTTP_AUTHORIZATION=f"Bearer {who.token}")
    resp.data = resp.json() if resp.content else None
    return resp


def tasks_of(project):
    return {t.title: t for t in Task.objects.filter(project_id=project["id"])}


def make_xlsx(rows, inline=False, extra_sheet=True, doctype=False):
    """rows: list of lists; strings go to sharedStrings (or inline), numbers stay numeric, tuples (f, v) are formulas."""
    shared: list[str] = []
    cells = []
    for r, row in enumerate(rows, start=1):
        out = []
        for c, value in enumerate(row):
            ref = f"{chr(65 + c)}{r}"
            if isinstance(value, tuple):
                out.append(f'<c r="{ref}"><f>{value[0]}</f>' + (f"<v>{value[1]}</v>" if value[1] else "") + "</c>")
            elif isinstance(value, (int, float)):
                out.append(f'<c r="{ref}"><v>{value}</v></c>')
            elif inline:
                out.append(f'<c r="{ref}" t="inlineStr"><is><t>{value}</t></is></c>')
            else:
                shared.append(value)
                out.append(f'<c r="{ref}" t="s"><v>{len(shared) - 1}</v></c>')
        cells.append(f'<row r="{r}">{"".join(out)}</row>')
    ns = 'xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"'
    sheet = f'<?xml version="1.0"?><worksheet {ns}><sheetData>{"".join(cells)}</sheetData></worksheet>'
    if doctype:
        sheet = '<?xml version="1.0"?><!DOCTYPE x [<!ENTITY a "b">]>' + sheet.split("?>", 1)[1]
    sst = f'<sst {ns}>' + "".join(f"<si><t>{s}</t></si>" for s in shared) + "</sst>"
    wb = (f'<workbook {ns} xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>'
          '<sheet name="One" sheetId="1" r:id="rId1"/><sheet name="Two" sheetId="2" r:id="rId2"/></sheets></workbook>')
    rels = ('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Target="worksheets/sheet1.xml"/>'
            '<Relationship Id="rId2" Target="worksheets/sheet2.xml"/></Relationships>')
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as zf:
        zf.writestr("xl/workbook.xml", wb)
        zf.writestr("xl/_rels/workbook.xml.rels", rels)
        zf.writestr("xl/sharedStrings.xml", sst)
        zf.writestr("xl/worksheets/sheet1.xml", sheet)
        if extra_sheet:
            zf.writestr("xl/worksheets/sheet2.xml", sheet.replace("<sheetData>", "<sheetData><row r='1'><c r='A1' t='inlineStr'><is><t>title</t></is></c></row><row r='2'><c r='A2' t='inlineStr'><is><t>SECOND SHEET</t></is></c></row>"))
    return buf.getvalue()


# --- csv --------------------------------------------------------------------------------------------------------


def test_csv_import_creates_tasks_columns_owners_and_checklists(crew, project):
    doing = next(c["title"] for c in project["columns"] if c["kind"] == "doing")
    body = (HEADER
            + f'Write copy,"Line one\nline two",2026-05-01T09:30:00+03:30,{doing},mia@corp.test,high,draft|review| |ship\n'
            + "Call client,,1405/02/11,Backlog,mel,urgent,\n"
            + "Plain,,,,,,\n")
    resp = push(crew.pam_d, project, "csv", ("﻿" + body).encode())
    assert resp.status_code == 200, resp.content
    assert resp.data == {"created": 3, "skipped": 0, "errors": [], "warnings": []}
    rows = tasks_of(project)
    copy = rows["Write copy"]
    assert copy.column.title == doing and copy.priority == "high" and copy.all_day is False
    assert copy.creator_id == crew.pam.id and copy.status == "open"
    assert [i.text for i in copy.checklist.order_by("rank")] == ["draft", "review", "ship"]
    assert TaskPerson.objects.get(task=copy).user_id == crew.mia.id
    call = rows["Call client"]
    assert call.column.title == "Backlog" and call.all_day is True and call.priority == "urgent"
    assert str(call.due_at.astimezone().date()) in ("2026-05-01", "2026-05-02")  # 1405/02/11 = 2026-05-01
    assert TaskPerson.objects.get(task=call).user_id == crew.mel.id  # matched by user name (email local part)
    assert rows["Plain"].column.kind == "todo" and TaskPerson.objects.get(task=rows["Plain"]).user_id == crew.pam.id
    assert BoardColumn.objects.filter(project_id=project["id"], title="Backlog").count() == 1
    ranks = [t.rank for t in Task.objects.filter(column=rows["Plain"].column).order_by("rank")]
    assert ranks == sorted(set(ranks))


def test_csv_row_errors_warnings_and_blank_rows(crew, project):
    body = (HEADER + ",no title,,,,,\n"
            + "Bad date,,not-a-date,,,,\n"
            + "Bad prio,,,,,huge,\n"
            + "Bad jalali,,1405/13/45,,,,\n"
            + "Stranger,,,,nobody@else.test,,\n"
            + "\n,,,,,,\n"
            + "Fine,,,,,,\n")
    resp = push(crew.pam_d, project, "csv", body.encode())
    assert resp.status_code == 200
    assert resp.data["created"] == 2 and resp.data["skipped"] == 4
    assert [(e["row"], e["message"][:5]) for e in resp.data["errors"]] == [(2, "title"), (3, "due i"), (4, "prior"), (5, "due i")]
    assert [w["row"] for w in resp.data["warnings"]] == [6]
    assert set(tasks_of(project)) == {"Stranger", "Fine"}


def test_header_rules_and_persian_digits(crew, project):
    assert push(crew.pam_d, project, "csv", b"name,description\nx,y\n").status_code == 422
    assert push(crew.pam_d, project, "csv", b"").status_code == 422
    assert push(crew.pam_d, project, "csv", b"\xff\xfe\x00bad").status_code == 422
    body = "TITLE , Due\nPersian,۱۴۰۵/۰۲/۱۱\n"
    assert push(crew.pam_d, project, "csv", body.encode()).data["created"] == 1


def test_text_is_stored_literally_and_control_characters_are_stripped(crew, project):
    body = HEADER + '"=HYPERLINK(""http://evil"")","x\x00y\x07z",,,,,"=1+1|@cmd"\n'
    assert push(crew.pam_d, project, "csv", body.encode()).data["created"] == 1
    task = Task.objects.get(project_id=project["id"])
    assert task.title == '=HYPERLINK("http://evil")'
    assert [i.text for i in task.checklist.all()] == ["=1+1", "@cmd"]
    from workspace.textbox import open_text
    assert open_text(task.description) == "xyz"
    assert "xyz" not in json.dumps(task.description)  # encrypted at rest


def test_caps_rows_and_size(crew, project):
    rows = HEADER + "t,,,,,,\n" * 2001
    assert push(crew.pam_d, project, "csv", rows.encode()).status_code == 422
    assert Task.objects.filter(project_id=project["id"]).count() == 0
    assert push(crew.pam_d, project, "csv", (HEADER + "t,,,,,,\n" * 2000).encode()).data["created"] == 2000
    big = b"title\n" + b"x" * (5 * 1024 * 1024 + 1)
    assert push(crew.pam_d, project, "csv", big).status_code == 413


def test_permissions_state_and_format(crew, project):
    data = (HEADER + "t,,,,,,\n").encode()
    expected = {"pam_d": 200, "mia_d": 403, "vic_d": 403, "out_d": 404, "boss": 404}
    for name, code in expected.items():
        assert push(getattr(crew, name), project, "csv", data).status_code == code, name
    assert push(crew.pam_d, project, "docx", data).status_code == 422
    crew.pam_d.call("patch", f"/projects/{project['id']}", {"status": "archived"})
    assert push(crew.pam_d, project, "csv", data).status_code == 409


def test_import_updates_progress_audits_ids_and_emits_one_event(crew, project):
    from workspace.models import Event
    push(crew.pam_d, project, "csv", (HEADER + "Secret title,,,,,,\nOther,,,,,,\n").encode())
    assert Event.objects.filter(kind="project.imported").count() == 1
    audit = AuditEvent.objects.get(action="project_imported")
    assert audit.data == {"format": "csv", "created": 2, "skipped": 0} and "Secret" not in str(audit.data)


# --- xlsx -------------------------------------------------------------------------------------------------------


def test_xlsx_first_sheet_shared_inline_and_serial_dates(crew, project):
    rows = [["title", "due", "owner_email", "checklist"], ["From sheet", 46143, "mia@corp.test", "a|b"], ["Second", "2026-06-01", "", ""]]
    for inline in (False, True):
        resp = push(crew.pam_d, project, "xlsx", make_xlsx(rows, inline=inline))
        assert resp.status_code == 200 and resp.data["created"] == 2, resp.content
    got = Task.objects.filter(project_id=project["id"], title="From sheet").first()
    assert str(got.due_at.astimezone().date()) == "2026-05-01" and got.all_day is True  # serial 46143
    assert not Task.objects.filter(title="SECOND SHEET").exists()


def test_xlsx_formulas_are_never_evaluated(crew, project):
    rows = [["title", "description"], [("1+1", "")], ["Cached", ("A1&amp;B1", "cached text")]]
    resp = push(crew.pam_d, project, "xlsx", make_xlsx(rows))
    assert resp.status_code == 200, resp.content
    task = Task.objects.get(project_id=project["id"], title="Cached") if resp.data["created"] else None
    assert task is not None
    from workspace.textbox import open_text
    assert open_text(task.description) == "cached text"


def test_xlsx_rejects_bad_files(crew, project):
    assert push(crew.pam_d, project, "xlsx", b"not a zip").status_code == 422
    assert push(crew.pam_d, project, "xlsx", make_xlsx([["title"], ["x"]], doctype=True)).status_code == 422
    many = [["title"]] + [["t"]] * 2001
    assert push(crew.pam_d, project, "xlsx", make_xlsx(many, extra_sheet=False)).status_code == 422


# --- trello -----------------------------------------------------------------------------------------------------


BOARD = {
    "name": "Board",
    "lists": [{"id": "l1", "name": "To do", "pos": 1}, {"id": "l2", "name": "Review", "pos": 2},
              {"id": "l3", "name": "Old", "pos": 3, "closed": True}],
    "labels": [{"id": "b1", "name": "urgent", "color": "red"}, {"id": "b2", "name": "", "color": "green"}],
    "members": [{"id": "m1", "username": "mia", "fullName": "Mia"}, {"id": "m2", "username": "zed"}],
    "cards": [
        {"id": "c1", "name": "First", "desc": "details", "due": "2026-05-01T08:00:00.000Z", "idList": "l1",
         "pos": 1, "idLabels": ["b1", "b2"], "idMembers": ["m1", "m2"], "closed": False},
        {"id": "c2", "name": "Done once", "idList": "l2", "pos": 1, "closed": True, "due": None},
        {"id": "c3", "name": "In archived list", "idList": "l3", "pos": 1},
        {"id": "c4", "name": "  ", "idList": "l1", "pos": 2},
    ],
    "checklists": [{"id": "k1", "idCard": "c1", "name": "x", "checkItems": [
        {"name": "second", "state": "incomplete", "pos": 2}, {"name": "first", "state": "complete", "pos": 1}]}],
}


def trello(who, project, board=BOARD):
    return push(who, project, "trello", json.dumps(board).encode())


def test_trello_import_maps_lists_cards_checklists_members(crew, project):
    resp = trello(crew.pam_d, project)
    assert resp.status_code == 200, resp.content
    assert resp.data["created"] == 2 and resp.data["skipped"] == 2
    assert {e["row"] for e in resp.data["errors"]} == {3, 4}
    titles = {c.title: c for c in BoardColumn.objects.filter(project_id=project["id"])}
    assert "Review" in titles and "Old" not in titles
    assert BoardColumn.objects.filter(project_id=project["id"], title="To do").count() == 1  # matched, not duplicated
    first = tasks_of(project)["First"]
    assert first.column.title == "To do" and first.all_day is False
    assert [(i.text, i.done) for i in first.checklist.order_by("rank")] == [("first", True), ("second", False)]
    assert TaskPerson.objects.get(task=first).user_id == crew.mia.id
    assert any(w["row"] == 1 and "person" in w["message"] for w in resp.data["warnings"])
    closed = tasks_of(project)["Done once"]
    assert closed.status == "cancelled" and closed.column.title == "Review"


def test_trello_labels_only_the_company_manager_creates_them(crew, project):
    crew.pam_d.call("put", f"/projects/{project['id']}/members", [
        {"user_id": crew.pam.id, "role": "manager"}, {"user_id": crew.boss.user.id if hasattr(crew.boss, "user") else crew.manager.id, "role": "manager"},
        {"user_id": crew.mia.id, "role": "member"}, {"user_id": crew.vic.id, "role": "viewer"},
        {"user_id": crew.mel.id, "role": "member"}])
    resp = trello(crew.pam_d, project)
    assert resp.status_code == 200
    labels = [w for w in resp.data["warnings"] if "label" in w["message"]]
    assert len(labels) == 2 and Label.objects.count() == 0 and SubjectLabel.objects.count() == 0
    resp = trello(crew.boss, project)
    assert resp.status_code == 200 and not [w for w in resp.data["warnings"] if "label" in w["message"]]
    assert sorted(Label.objects.values_list("name", "scope")) == [("green", "org"), ("urgent", "org")]
    assert SubjectLabel.objects.count() == 2


def test_trello_matches_existing_personal_label_for_anyone(crew, project):
    crew.pam_d.call("post", "/labels", {"name": "URGENT", "scope": "personal"})
    resp = trello(crew.pam_d, project)
    assert SubjectLabel.objects.count() == 1 and len([w for w in resp.data["warnings"] if "label" in w["message"]]) == 1


def test_trello_rejects_bad_json(crew, project):
    assert push(crew.pam_d, project, "trello", b"{nope").status_code == 422
    assert push(crew.pam_d, project, "trello", b'{"x": 1}').status_code == 422
    assert push(crew.pam_d, project, "trello", b"[1,2]").status_code == 422
    many = {"lists": [{"id": "l", "name": "A"}], "cards": [{"id": str(i), "name": "n", "idList": "l"} for i in range(2001)]}
    assert trello(crew.pam_d, project, many).status_code == 422
