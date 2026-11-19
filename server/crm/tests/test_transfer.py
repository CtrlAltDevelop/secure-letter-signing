from crm.models import Customer, CustomerMember


def transfer(who, source, target):
    return who.call("post", f"/users/{source.id}/transfer", {"to_user_id": target.id})


def members(file_id):
    return {m.user.email.split("@")[0]: (m.role, m.active) for m in CustomerMember.objects.filter(customer_id=file_id)
            .select_related("user")}


def test_owner_and_memberships_move_keeping_roles(team, file, make_user, login):
    new = make_user("new@corp.test", grants=("customer.create",))
    resp = transfer(team.boss, team.ann, new)
    assert resp.status_code == 200 and resp.data["moved"]["crm"] == 1
    assert Customer.objects.get(pk=file["id"]).owner_id == new.id
    state = members(file["id"])
    assert state["ann"][1] is False and state["new"] == ("manager", True)
    assert state["bob"] == ("member", True) and state["vic"] == ("viewer", True)
    assert login(new).call("get", f"/customers/{file['id']}").status_code == 200
    assert team.ann_d.call("get", f"/customers/{file['id']}").status_code == 404


def test_member_role_is_kept(team, file, make_user):
    new = make_user("new@corp.test")
    assert transfer(team.boss, team.vic, new).data["moved"]["crm"] == 1
    assert members(file["id"])["new"] == ("viewer", True)


def test_target_with_higher_role_keeps_it_and_nothing_counts(team, file):
    resp = transfer(team.boss, team.vic, team.bob)  # vic is a viewer, bob already a member
    assert resp.data["moved"]["crm"] == 0
    state = members(file["id"])
    assert state["bob"] == ("member", True) and state["vic"][1] is False


def test_lower_target_role_is_upgraded(team, file):
    resp = transfer(team.boss, team.bob, team.vic)  # bob member -> vic viewer becomes member
    assert resp.data["moved"]["crm"] == 1
    assert members(file["id"])["vic"] == ("member", True)


def test_inactive_source_and_unrelated_files_untouched(team, file):
    team.out_d.call("post", "/customers", {"name": "Other"})
    team.ann.is_active = False
    team.ann.save()
    assert transfer(team.boss, team.ann, team.out).data["moved"]["crm"] == 1
    assert Customer.objects.filter(owner=team.out).count() == 2
