import pytest
from django.db import transaction
from django.db.utils import DatabaseError

from polls.models import Poll, PollAnswer
from workspace.models import Event
from workspace.tests.conftest import *  # noqa: F401,F403  (api, make_user, manager, login, brand_dir)


@pytest.fixture(autouse=True)
def _all_modules(brand_dir):
    brand_dir()


@pytest.fixture
def team(make_user, login, manager):
    """cat owns the project (its manager), mia and max are members, out is not involved."""
    team = type("Team", (), {})()
    team.manager, team.boss = manager, login(manager)
    for name in ("cat", "mia", "max", "out"):
        user = make_user(f"{name}@corp.test", grants=("project.create", "task.create"))
        setattr(team, name, user)
        setattr(team, f"{name}_d", login(user))
    proj = team.cat_d.call("post", "/projects", {"name": "P", "members": [
        {"user_id": team.mia.id, "role": "member"}, {"user_id": team.max.id, "role": "member"}]})
    assert proj.status_code == 201, proj.content
    team.target = proj.data["subject_id"]
    return team


QUESTIONS = [{"text": "Lunch?", "options": ["Pizza", "Sushi"]},
             {"text": "Days?", "multiple": True, "options": ["Mon", "Tue", "Wed"]}]


def _poll(team, who="mia_d", **over):
    body = {"target_subject_id": team.target, "title": "Team poll", "questions": QUESTIONS, **over}
    resp = getattr(team, who).call("post", "/polls", body)
    assert resp.status_code == 201, resp.content
    return resp.data


def _answers(poll, picks):
    """picks: one list of option indexes per question."""
    return {"answers": [{"question_id": q["id"], "option_ids": [q["options"][i]["id"] for i in idx]}
                        for q, idx in zip(poll["questions"], picks)]}


def test_create_and_visibility(team):
    poll = _poll(team)
    assert poll["status"] == "open" and poll["kind"] == "poll" and poll["question_count"] == 2
    assert poll["can"]["submit"] and poll["can"]["close"] and poll["participants"] == 0
    assert team.max_d.call("get", f"/polls/{poll['id']}").status_code == 200
    assert team.out_d.call("get", f"/polls/{poll['id']}").status_code == 404
    assert team.boss.call("get", f"/polls/{poll['id']}").status_code == 404
    assert team.out_d.call("post", "/polls", {"target_subject_id": team.target, "title": "x",
                                              "questions": QUESTIONS}).status_code == 404
    assert Event.objects.filter(kind="poll.created", recipients__user=team.max).exists()
    assert not Event.objects.filter(kind="poll.created", recipients__user=team.mia).exists()


def test_creation_validation(team):
    base = {"target_subject_id": team.target, "title": "t"}
    assert team.mia_d.call("post", "/polls", {**base, "questions": []}).status_code == 422
    one = {"text": "q", "options": ["only"]}
    assert team.mia_d.call("post", "/polls", {**base, "questions": [one]}).status_code == 422
    correct = {"text": "q", "options": ["a", "b"], "correct": [0]}
    assert team.mia_d.call("post", "/polls", {**base, "questions": [correct]}).status_code == 422
    nocorrect = {"text": "q", "options": ["a", "b"]}
    assert team.mia_d.call("post", "/polls", {**base, "kind": "quiz", "questions": [nocorrect]}).status_code == 422
    past = {**base, "questions": QUESTIONS, "closes_at": "2000-01-01T00:00:00Z"}
    assert team.mia_d.call("post", "/polls", past).status_code == 422


def test_submit_replace_and_validation(team):
    poll = _poll(team)
    path = f"/polls/{poll['id']}/submit"
    assert team.max_d.call("post", path, {"answers": []}).status_code == 422
    assert team.max_d.call("post", path, _answers(poll, [[0, 1], [0]])).status_code == 422  # single-choice
    assert team.max_d.call("post", path, {"answers": [{"question_id": 999, "option_ids": [1]}]}).status_code == 422
    foreign = _answers(poll, [[0], [0]])
    foreign["answers"][0]["option_ids"] = [poll["questions"][1]["options"][0]["id"]]
    assert team.max_d.call("post", path, foreign).status_code == 422
    first = team.max_d.call("post", path, _answers(poll, [[0], [0, 1]]))
    assert first.status_code == 200 and first.data["i_submitted"] and first.data["participants"] == 1
    again = team.max_d.call("post", path, _answers(poll, [[1], [2]]))
    assert again.data["participants"] == 1
    mine = again.data["my_answers"]
    assert mine[str(poll["questions"][0]["id"])] == [poll["questions"][0]["options"][1]["id"]]
    assert PollAnswer.objects.filter(user=team.max, active=True).count() == 2
    assert PollAnswer.objects.filter(user=team.max, active=False).count() == 3  # replaced, never deleted
    assert team.out_d.call("post", path, _answers(poll, [[0], [0]])).status_code == 404


def test_public_results_show_voters_after_voting(team):
    poll = _poll(team)
    assert team.max_d.call("get", f"/polls/{poll['id']}/results").status_code == 403  # vote first
    team.max_d.call("post", f"/polls/{poll['id']}/submit", _answers(poll, [[0], [0, 2]]))
    team.mia_d.call("post", f"/polls/{poll['id']}/submit", _answers(poll, [[0], [2]]))
    res = team.max_d.call("get", f"/polls/{poll['id']}/results").data
    assert res["participants"] == 2
    pizza = res["questions"][0]["options"][0]
    assert pizza["count"] == 2 and {v["id"] for v in pizza["voters"]} == {team.max.id, team.mia.id}
    assert res["questions"][1]["options"][2]["count"] == 2 and res["scores"] is None


def test_anonymous_to_users_hides_voters_from_plain_users_only(team):
    poll = _poll(team, anonymity="anonymous_to_users")
    team.max_d.call("post", f"/polls/{poll['id']}/submit", _answers(poll, [[1], [1]]))
    plain = team.max_d.call("get", f"/polls/{poll['id']}/results").data
    assert plain["questions"][0]["options"][1]["count"] == 1 and plain["questions"][0]["options"][1]["voters"] is None
    creator = team.mia_d.call("get", f"/polls/{poll['id']}/results").data
    assert creator["questions"][0]["options"][1]["voters"][0]["id"] == team.max.id
    manager = team.cat_d.call("get", f"/polls/{poll['id']}/results").data  # the project's manager may moderate
    assert manager["questions"][0]["options"][1]["voters"][0]["id"] == team.max.id


def test_anonymous_to_all_hides_voters_from_everyone_including_export(team):
    poll = _poll(team, anonymity="anonymous_to_all")
    team.max_d.call("post", f"/polls/{poll['id']}/submit", _answers(poll, [[1], [1]]))
    for who in (team.mia_d, team.cat_d):
        res = who.call("get", f"/polls/{poll['id']}/results").data
        assert all(o["voters"] is None for q in res["questions"] for o in q["options"])
    exp = team.mia_d.call("get", f"/polls/{poll['id']}/results/export")
    assert exp.status_code == 200 and all(r["voters"] is None for r in exp.data["rows"])
    assert team.max_d.call("get", f"/polls/{poll['id']}/results/export").status_code == 403


def test_close_rules_and_immutability(team):
    poll = _poll(team)
    pid = poll["id"]
    team.max_d.call("post", f"/polls/{pid}/submit", _answers(poll, [[0], [0]]))
    assert team.max_d.call("post", f"/polls/{pid}/close").status_code == 403
    assert team.out_d.call("post", f"/polls/{pid}/close").status_code == 404
    closed = team.cat_d.call("post", f"/polls/{pid}/close")  # target manager
    assert closed.status_code == 200 and closed.data["status"] == "closed"
    assert team.cat_d.call("post", f"/polls/{pid}/close").status_code == 409
    assert team.max_d.call("post", f"/polls/{pid}/submit", _answers(poll, [[1], [1]])).status_code == 409
    assert team.mia_d.call("post", f"/polls/{pid}/submit", _answers(poll, [[1], [1]])).status_code == 409
    assert team.mia_d.call("get", f"/polls/{pid}/results").status_code == 200  # closed: results open to all
    assert Event.objects.filter(kind="poll.closed", recipients__user=team.max).exists()
    assert Poll.objects.get(pk=pid).closed_by_id == team.cat.id


def test_closes_at_passing_closes_the_poll(team):
    poll = _poll(team, closes_at="2099-01-01T00:00:00Z")
    Poll.objects.filter(pk=poll["id"]).update(closes_at="2000-01-01T00:00:00Z")
    assert team.max_d.call("get", f"/polls/{poll['id']}").data["status"] == "closed"
    assert team.max_d.call("post", f"/polls/{poll['id']}/submit", _answers(poll, [[0], [0]])).status_code == 409


QUIZ = [{"text": "2+2?", "options": ["3", "4"], "correct": [1], "points": 2},
        {"text": "Primes?", "multiple": True, "options": ["2", "3", "4"], "correct": [0, 1], "points": 3}]


def test_quiz_scores_reveal_and_export(team):
    poll = _poll(team, kind="quiz", questions=QUIZ)
    assert all(q["correct_option_ids"] is not None for q in poll["questions"])  # creator sees the key
    pid = poll["id"]
    seen = team.max_d.call("get", f"/polls/{pid}").data
    assert all(q["correct_option_ids"] is None for q in seen["questions"])  # hidden while open
    team.max_d.call("post", f"/polls/{pid}/submit", _answers(seen, [[1], [0, 1]]))  # 2 + 3
    team.cat_d.call("post", f"/polls/{pid}/submit", _answers(seen, [[1], [0]]))  # 2 + 0 (partial is wrong)
    res = team.mia_d.call("get", f"/polls/{pid}/results").data
    scores = {s["user"]["id"]: s["score"] for s in res["scores"]}
    assert scores == {team.max.id: 5, team.cat.id: 2} and res["max_score"] == 5 and res["my_score"] is None
    plain = team.max_d.call("get", f"/polls/{pid}/results").data
    assert plain["scores"] is None and plain["my_score"] is None and plain["questions"][0]["correct_option_ids"] is None
    team.mia_d.call("post", f"/polls/{pid}/close")
    after = team.max_d.call("get", f"/polls/{pid}/results").data
    assert after["my_score"] == 5 and after["questions"][0]["correct_option_ids"] is not None
    exp = team.mia_d.call("get", f"/polls/{pid}/results/export").data
    assert exp["participants"] == 2 and exp["kind"] == "quiz" and len(exp["rows"]) == 5
    assert {s["participant"]: s["score"] for s in exp["scores"]} == {team.max.email: 5, team.cat.email: 2}
    assert any(r["correct"] is True for r in exp["rows"])


def test_quiz_scores_hidden_for_anonymous_to_all(team):
    poll = _poll(team, kind="quiz", anonymity="anonymous_to_all", questions=QUIZ)
    team.max_d.call("post", f"/polls/{poll['id']}/submit", _answers(poll, [[1], [0, 1]]))
    res = team.mia_d.call("get", f"/polls/{poll['id']}/results").data
    assert res["scores"] is None and res["participants"] == 1


def test_listing_filters(team):
    on_project = _poll(team, title="A")
    team.cat_d.call("post", f"/polls/{on_project['id']}/close")
    second = _poll(team, who="max_d", title="B")
    names = lambda who, q="": [p["title"] for p in getattr(team, who).call("get", f"/polls{q}").data]  # noqa: E731
    assert names("cat_d") == ["B", "A"]
    assert names("cat_d", "?status=open") == ["B"] and names("cat_d", "?status=closed") == ["A"]
    assert names("max_d", "?mine=true") == ["B"]
    assert names("cat_d", f"?target_subject={team.target}") == ["B", "A"]
    assert names("out_d") == [] and names("boss") == []
    assert second["creator"]["id"] == team.max.id


def test_templates_and_create_from_template(team):
    data = {"title": "Standup", "kind": "quiz", "anonymity": "anonymous_to_users", "questions": QUIZ}
    tpl = team.mia_d.call("post", "/poll-templates", {"name": "Quiz T", "data": data})
    assert tpl.status_code == 201 and tpl.data["scope"] == "personal"
    assert team.mia_d.call("post", "/poll-templates", {"name": "O", "scope": "org", "data": data}).status_code == 403
    assert team.boss.call("post", "/poll-templates", {"name": "O", "scope": "org", "data": data}).status_code == 201
    assert len(team.max_d.call("get", "/poll-templates").data) == 1
    bad = {**data, "questions": [{"text": "q", "options": ["a", "b"]}]}
    assert team.mia_d.call("post", "/poll-templates", {"name": "B", "data": bad}).status_code == 422
    made = team.mia_d.call("post", "/polls", {"target_subject_id": team.target, "template_id": tpl.data["id"]})
    assert made.status_code == 201 and made.data["title"] == "Standup" and made.data["kind"] == "quiz"
    assert made.data["anonymity"] == "anonymous_to_users" and len(made.data["questions"]) == 2
    assert team.mia_d.call("patch", f"/poll-templates/{tpl.data['id']}", {"active": False}).data["active"] is False
    again = team.mia_d.call("post", "/polls", {"target_subject_id": team.target, "template_id": tpl.data["id"]})
    assert again.status_code == 422
    assert team.max_d.call("patch", f"/poll-templates/{tpl.data['id']}", {"name": "x"}).status_code == 404


def test_poll_subject_collaboration_and_no_hard_delete(team):
    poll = _poll(team)
    sid = poll["subject_id"]
    assert team.max_d.call("post", f"/subjects/{sid}/comments", {"body": {"text": "ok"}}).status_code == 201
    assert team.out_d.call("get", f"/subjects/{sid}/comments").status_code == 404
    with pytest.raises(DatabaseError), transaction.atomic():
        PollAnswer.objects.all().delete()
        Poll.objects.all().delete()


def test_module_off(team, brand_dir):
    brand_dir(modules=["projects"])
    assert team.cat_d.call("get", "/polls").status_code == 404
