from accounts.models import OrgTitle
from workspace.schemas import user_ref


def test_user_ref_carries_company_title_and_status(make_user):
    user = make_user("a@corp.test")
    ref = user_ref(user)
    assert ref.model_dump() == {"id": user.id, "full_name": "", "email": "a@corp.test", "title": "", "status_text": ""}
    user.org_title, user.status_text = OrgTitle.objects.create(name="Lead"), "Away"
    user.save()
    ref = user_ref(user)
    assert (ref.title, ref.status_text) == ("Lead", "Away")
