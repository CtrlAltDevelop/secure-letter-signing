from tasks.tests.test_templates import BODY


def test_from_template_into_a_project_drops_non_members_and_sets_column(crew, project):
    out = crew.pam_d.call("post", "/task-templates", {"name": "P", "data": {
        **BODY, "owners": ["me", crew.mia.id, crew.out.id], "followers": [crew.vic.id]}}).data
    doing = next(c["id"] for c in project["columns"] if c["kind"] == "doing")
    resp = crew.pam_d.call("post", "/tasks/from-template", {
        "template_id": out["id"], "project_id": project["id"], "column_id": doing})
    assert resp.status_code == 201, resp.content
    assert sorted(o["id"] for o in resp.data["owners"]) == sorted([crew.pam.id, crew.mia.id])
    assert resp.data["project_id"] == project["id"] and resp.data["column_id"] == doing
    denied = crew.out_d.call("post", "/tasks/from-template", {"template_id": out["id"], "project_id": project["id"]})
    assert denied.status_code in (403, 404)
