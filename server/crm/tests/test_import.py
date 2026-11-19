import io
import zipfile

from django.core.files.uploadedfile import SimpleUploadedFile

from core import xlsx
from crm.models import Customer

HEADER = "kind,name,legal_name,national_id,phone,mobile,email,address,status\n"


def upload(client, content: bytes, fmt: str = "csv", name: str = "customers.csv"):
    api = client.api
    resp = api.client.post("/api/customers/import", {"format": fmt, "file": SimpleUploadedFile(name, content)},
                           HTTP_AUTHORIZATION=f"Bearer {client.token}")
    resp.data = resp.json() if resp.content else None
    return resp


def make_xlsx(rows: list[list[str]]) -> bytes:
    """A tiny workbook with shared strings, for the reader tests."""
    strings: list[str] = []
    cells = []
    for r, row in enumerate(rows, start=1):
        out = []
        for c, value in enumerate(row):
            if value == "":
                continue
            strings.append(value)
            out.append(f'<c r="{chr(65 + c)}{r}" t="s"><v>{len(strings) - 1}</v></c>')
        cells.append(f'<row r="{r}">{"".join(out)}</row>')
    ns = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    parts = {
        "xl/workbook.xml": f'<workbook xmlns="{ns}" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/'
                           f'relationships"><sheets><sheet name="S" sheetId="1" r:id="rId1"/></sheets></workbook>',
        "xl/_rels/workbook.xml.rels": '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/'
                                      'relationships"><Relationship Id="rId1" Target="worksheets/sheet1.xml"/>'
                                      '</Relationships>',
        "xl/sharedStrings.xml": f'<sst xmlns="{ns}">' + "".join(f"<si><t>{s}</t></si>" for s in strings) + "</sst>",
        "xl/worksheets/sheet1.xml": f'<worksheet xmlns="{ns}"><sheetData>{"".join(cells)}</sheetData></worksheet>',
    }
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as zf:
        for name, text in parts.items():
            zf.writestr(name, text)
    return buf.getvalue()


def test_import_creates_skips_and_reports(team, make_user, login):
    importer = make_user("imp@corp.test", grants=("customer.import",))
    d = login(importer)
    existing = team.ann_d.call("post", "/customers", {"name": "Old", "national_id": "111", "email": "old@x.test"})
    assert existing.status_code == 201
    csv_text = HEADER + (
        "company,New Co,New Company Ltd,222,021,0912,NEW@x.test,Main St,active\n"
        "person,Dup National,,111,,,,,\n"
        ",Dup Email,,,,,OLD@x.test,,\n"
        "person,,,,,,,,\n"
        "alien,Bad Kind,,,,,,,\n"
        "person,Bad Mail,,,,,not-mail,,\n"
        "person,Bad Status,,,,,,,gone\n"
        "person,Repeat,,222,,,,,\n"
        "\n"
        "person,Plain,,,,,,,inactive\n")
    resp = upload(d, csv_text.encode("utf-8-sig"))
    assert resp.status_code == 200, resp.content
    assert resp.data["created"] == 2 and resp.data["skipped"] == 3
    assert [(e["row"], e["message"]) for e in resp.data["errors"]] == [
        (5, "name is required"), (6, "kind must be person or company"), (7, "email is not valid"),
        (8, "status must be active, inactive or archived")]
    new = Customer.objects.get(name="New Co")
    assert new.email == "new@x.test" and new.owner == importer and new.legal_name == "New Company Ltd"
    assert d.call("get", f"/customers/{new.id}").data["address"] == {"text": "Main St"}
    assert Customer.objects.get(name="Plain").status == "inactive"
    assert d.call("get", "/customers").data  # the importer is manager of what they imported


def test_import_needs_permission_and_valid_input(team, make_user, login):
    assert upload(team.ann_d, (HEADER + "person,A\n").encode()).status_code == 403
    d = login(make_user("imp2@corp.test", grants=("customer.import",)))
    assert upload(d, b"foo,bar\n1,2\n").status_code == 422  # no name column
    assert upload(d, b"").status_code == 422
    assert upload(d, b"\xff\xfe\x00", "csv").status_code == 422
    assert upload(d, b"abc", "pdf").status_code == 422
    assert upload(d, b"not a zip", "xlsx").status_code == 422
    rows = "".join(f"person,N{i}\n" for i in range(5001))
    assert upload(d, (HEADER + rows).encode()).status_code == 422
    assert upload(d, b"name\n" + b"x" * (5 * 1024 * 1024 + 1)).status_code == 413
    assert Customer.objects.count() == 0


def test_import_respects_the_limit(team, make_user, login, settings):
    settings.CUSTOMER_LIMIT = 1
    d = login(make_user("imp3@corp.test", grants=("customer.import",)))
    resp = upload(d, (HEADER + "person,One\nperson,Two\n").encode())
    assert resp.data["created"] == 1 and resp.data["errors"] == [{"row": 3, "message": "Customer limit reached"}]


def test_import_xlsx(team, make_user, login):
    d = login(make_user("imp4@corp.test", grants=("customer.import",)))
    data = make_xlsx([["name", "kind", "mobile"], ["Xl One", "company", "0912"], ["Xl Two", "", ""]])
    resp = upload(d, data, "xlsx", "c.xlsx")
    assert resp.status_code == 200 and resp.data["created"] == 2, resp.content
    assert Customer.objects.get(name="Xl One").kind == "company"


def test_xlsx_reader_rows_and_hardening():
    rows = xlsx.read_first_sheet(make_xlsx([["a", "b"], ["", "c"], ["d"]]))
    assert rows == [["a", "b"], ["", "c"], ["d"]]
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as zf:
        zf.writestr("xl/workbook.xml", '<!DOCTYPE x [<!ENTITY a "b">]><workbook/>')
    try:
        xlsx.read_first_sheet(buf.getvalue())
    except xlsx.XlsxError:
        pass
    else:
        raise AssertionError("DOCTYPE must be refused")
