from accounts.models import AuditEvent, Notification
from projects.models import Project, ProjectMember
from tasks.models import Task, TaskPerson, TaskTemplate
from workspace import registry
from workspace.models import ChangeHistory


def transfer(who, source, target):
    return who.call("post", f"/users/{source.id}/transfer", {"to_user_id": target.id})


def roles(task_id, user):
    return sorted(TaskPerson.objects.filter(task_id=task_id, user=user, active=True).values_list("role", flat=True))


def test_manager_only_and_validation(crew):
    assert transfer(crew.pam_d, crew.mia, crew.mel).status_code == 403
    assert transfer(crew.boss, crew.mia, crew.mia).status_code == 422
    crew.mel.is_active = False
    crew.mel.save()
    assert transfer(crew.boss, crew.mia, crew.mel).status_code == 422
    assert crew.boss.call("post", "/users/99999/transfer", {"to_user_id": crew.pam.id}).status_code == 404
    assert crew.boss.call("post", f"/users/{crew.mia.id}/transfer", {"to_user_id": 99999}).status_code == 404


def test_moves_open_tasks_people_creator_and_memberships(crew, project, make_ptask, django_capture_on_commit_callbacks):
    owned = make_ptask(who=crew.pam_d, owner_ids=[crew.mia.id, crew.pam.id], follower_ids=[crew.mia.id])
    created = make_ptask(who=crew.mia_d, owner_ids=[crew.pam.id])
    done = make_ptask(who=crew.pam_d, owner_ids=[crew.mia.id])
    crew.mia_d.call("post", f"/tasks/{done['id']}/complete")
    unrelated = make_ptask(who=crew.pam_d, owner_ids=[crew.pam.id])
    with django_capture_on_commit_callbacks(execute=True):
        resp = transfer(crew.boss, crew.mia, crew.mel)
    assert resp.status_code == 200, resp.content
    assert {k: resp.data["moved"][k] for k in ("projects", "tasks", "task_templates", "crm", "sales")} == {
        "projects": 1, "tasks": 2, "task_templates": 0, "crm": 0, "sales": 0}
    assert roles(owned["id"], crew.mia) == [] and roles(owned["id"], crew.mel) == ["follower", "owner"]
    assert roles(owned["id"], crew.pam) == ["owner"]
    assert Task.objects.get(pk=created["id"]).creator_id == crew.mel.id
    assert roles(done["id"], crew.mia) == ["owner"]  # closed tasks stay
    assert roles(unrelated["id"], crew.mel) == []
    member = {m.user_id: (m.role, m.active) for m in ProjectMember.objects.filter(project_id=project["id"])}
    assert member[crew.mia.id][1] is False and member[crew.mel.id] == ("member", True)
    assert Notification.objects.filter(user=crew.mel, kind="work.transferred").count() == 1
    assert ChangeHistory.objects.filter(field="transfer", subject__task__pk=owned["id"]).count() == 1
    assert crew.mel_d.call("get", f"/tasks/{owned['id']}").status_code == 200


def test_source_may_be_inactive_and_ownership_moves(crew, project, make_ptask):
    other = crew.mia_d.call("post", "/projects", {"name": "Mine", "members": [
        {"user_id": crew.mel.id, "role": "viewer"}]}).data
    crew.mia.is_active = False
    crew.mia.save()
    resp = transfer(crew.boss, crew.mia, crew.mel)
    assert resp.status_code == 200 and resp.data["moved"]["projects"] == 2
    row = Project.objects.get(pk=other["id"])
    assert row.owner_id == crew.mel.id
    assert ProjectMember.objects.get(project=row, user=crew.mel).role == "manager"  # viewer upgraded, owner is manager
    assert ProjectMember.objects.get(project=row, user=crew.mia).active is False


def test_higher_existing_role_is_kept(crew, project):
    crew.pam_d.call("put", f"/projects/{project['id']}/members", [
        {"user_id": crew.pam.id, "role": "manager"}, {"user_id": crew.mia.id, "role": "viewer"},
        {"user_id": crew.mel.id, "role": "member"}])
    transfer(crew.boss, crew.mia, crew.mel)
    assert ProjectMember.objects.get(project_id=project["id"], user=crew.mel).role == "member"


def test_awaiting_approver_is_replaced_and_asked(team, make_task, django_capture_on_commit_callbacks):
    flow = make_task(approver_ids=[team.abe.id, team.ben.id])
    team.olga_d.call("post", f"/tasks/{flow['id']}/complete")
    with django_capture_on_commit_callbacks(execute=True):
        assert transfer(team.boss, team.abe, team.fay).status_code == 200
    task = team.cat_d.call("get", f"/tasks/{flow['id']}").data
    assert [a["user"]["id"] for a in task["approvers"]] == [team.ben.id, team.fay.id] or \
        {a["user"]["id"] for a in task["approvers"]} == {team.fay.id, team.ben.id}
    assert team.fay_d.call("post", f"/tasks/{flow['id']}/decision", {"decision": "approve"}).status_code == 200
    assert Notification.objects.filter(user=team.fay, kind="task.approval_needed").count() == 1


def test_templates_move_and_audit_has_ids_only(team, make_task):
    team.cat_d.call("post", "/task-templates", {"name": "Secret template", "data": {"title": "T"}})
    make_task()
    resp = transfer(team.boss, team.cat, team.fay)
    assert resp.data["moved"]["task_templates"] == 1 and resp.data["moved"]["tasks"] == 1
    assert TaskTemplate.objects.get().owner_id == team.fay.id
    events = AuditEvent.objects.filter(action="work_transferred")
    assert events.count() == 1 and events[0].data["moved"]["tasks"] == 1
    assert "Quarterly" not in str(events[0].data) and "Secret" not in str(events[0].data)


def test_other_modules_plug_in_through_the_registry(team, make_task, brand_dir):
    brand_dir()
    seen = []
    registry.register(registry.ModuleSpec("chatty", None, lambda s: None, lambda u, o, a: False,
                                          transfer=lambda f, t, actor: seen.append((f.id, t.id, actor.id)) or 5))
    try:
        resp = transfer(team.boss, team.cat, team.fay)
    finally:
        registry.unregister("chatty")
    assert resp.data["moved"]["chatty"] == 5 and seen == [(team.cat.id, team.fay.id, team.manager.id)]


def test_everything_is_rolled_back_when_a_module_fails(team, make_task, brand_dir):
    brand_dir()
    task = make_task()

    def boom(f, t, actor):
        raise RuntimeError("module failed")

    registry.register(registry.ModuleSpec("zzz", None, lambda s: None, lambda u, o, a: False, transfer=boom))
    try:
        try:
            transfer(team.boss, team.cat, team.fay)
        except RuntimeError:
            pass
    finally:
        registry.unregister("zzz")
    assert Task.objects.get(pk=task["id"]).creator_id == team.cat.id
    assert not AuditEvent.objects.filter(action="work_transferred").exists()
