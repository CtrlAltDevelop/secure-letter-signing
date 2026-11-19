from sales.models import Lead
from sales.tests.conftest import lead_body
from sales.transfer import transfer as sales_transfer


def transfer(who, source, target):
    return who.call("post", f"/users/{source.id}/transfer", {"to_user_id": target.id})


def test_open_leads_move_owner_and_creator_closed_stay(team):
    mine = team.ann_d.call("post", "/sales/leads", lead_body()).data
    handed = team.ann_d.call("post", "/sales/leads", lead_body(owner_id=team.bob.id)).data  # ann created, bob owns
    won = team.ann_d.call("post", "/sales/leads", lead_body()).data
    assert team.ann_d.call("post", f"/sales/leads/{won['id']}/win").status_code == 200
    other = team.bob_d.call("post", "/sales/leads", lead_body()).data
    resp = transfer(team.boss, team.ann, team.cat)
    assert resp.status_code == 200 and resp.data["moved"]["sales"] == 2
    row = Lead.objects.get(pk=mine["id"])
    assert row.owner_id == team.cat.id and row.created_by_id == team.cat.id
    row = Lead.objects.get(pk=handed["id"])
    assert row.owner_id == team.bob.id and row.created_by_id == team.cat.id
    assert Lead.objects.get(pk=won["id"]).owner_id == team.ann.id
    assert Lead.objects.get(pk=other["id"]).owner_id == team.bob.id


def test_target_without_permission_gets_nothing(team):
    team.ann_d.call("post", "/sales/leads", lead_body())
    assert transfer(team.boss, team.ann, team.plain).data["moved"]["sales"] == 0
    assert Lead.objects.get().owner_id == team.ann.id


def test_customer_lead_needs_target_membership(team, customer):
    linked = team.ann_d.call("post", "/sales/leads", lead_body(customer_id=customer["id"])).data
    free = team.ann_d.call("post", "/sales/leads", lead_body()).data
    assert sales_transfer(team.ann, team.cat, team.manager) == 1  # cat is not on the customer file
    assert Lead.objects.get(pk=linked["id"]).owner_id == team.ann.id
    assert Lead.objects.get(pk=free["id"]).owner_id == team.cat.id


def test_whole_transfer_moves_file_membership_first_so_linked_leads_follow(team, customer):
    linked = team.ann_d.call("post", "/sales/leads", lead_body(customer_id=customer["id"])).data
    assert transfer(team.boss, team.ann, team.cat).data["moved"]["sales"] == 1  # crm runs before sales
    assert Lead.objects.get(pk=linked["id"]).owner_id == team.cat.id
