"""Results, quiz scoring, export. Anonymity is enforced here: voters and per-person scores are never computed for
callers who may not see them."""
from collections import defaultdict
from uuid import UUID

from django.shortcuts import get_object_or_404
from ninja.errors import HttpError

from accounts.models import User
from workspace.schemas import user_ref

from . import rules
from .models import Poll, PollAnswer, PollQuestion, PollSubmission
from .schemas import ExportOut, ExportRow, OptionResult, QuestionResult, ResultsOut, ScoreOut


def has_submitted(user: User, poll: Poll) -> bool:
    return PollSubmission.objects.filter(poll=poll, user=user).exists()


def can_see_results(user: User, poll: Poll) -> bool:
    """Everyone with access sees results once they voted or the poll is closed; the creator/moderators any time."""
    return rules.can_moderate(user, poll) or rules.is_closed(poll) or has_submitted(user, poll)


def _answers(poll: Poll) -> dict[int, dict[int, set[int]]]:
    """question id -> user id -> chosen option ids (active answers only)."""
    out: dict = defaultdict(lambda: defaultdict(set))
    rows = PollAnswer.objects.filter(question__poll=poll, active=True).values_list("question_id", "user_id", "option_id")
    for qid, uid, oid in rows:
        out[qid][uid].add(oid)
    return out


def question_score(question: PollQuestion, chosen: set[int]) -> int:
    """Full points when the chosen options are exactly the correct ones, else 0."""
    return question.points if chosen and chosen == set(question.correct_option_ids) else 0


def scores_by_user(poll: Poll, answers: dict) -> dict[int, int]:
    totals = {uid: 0 for uid in PollSubmission.objects.filter(poll=poll).values_list("user_id", flat=True)}
    for question in poll.questions.all():
        for uid, chosen in answers[question.id].items():
            totals[uid] = totals.get(uid, 0) + question_score(question, chosen)
    return totals


def _max_score(poll: Poll) -> int:
    return sum(q.points for q in poll.questions.all())


def _question_result(q: PollQuestion, per_user: dict, users: dict | None, reveal: bool) -> QuestionResult:
    options = []
    for opt in q.options.order_by("rank", "id"):
        voters = [uid for uid, chosen in per_user.items() if opt.id in chosen]
        options.append(OptionResult(id=opt.id, text=opt.text, count=len(voters),
                                    voters=[user_ref(users[u]) for u in sorted(voters)] if users is not None else None))
    return QuestionResult(id=q.id, text=q.text, multiple=q.multiple, points=q.points, options=options,
                          correct_option_ids=q.correct_option_ids if reveal else None)


def _load(user: User, poll_id: UUID) -> Poll:
    poll = get_object_or_404(Poll.objects.select_related("target_subject", "creator"), pk=poll_id)
    if not rules.can_see(user, poll):
        raise HttpError(404, "Not found")
    return poll


def results(user: User, poll_id: UUID) -> ResultsOut:
    poll = _load(user, poll_id)
    if not can_see_results(user, poll):
        raise HttpError(403, "Vote first to see the results")
    answers = _answers(poll)
    voters_visible = rules.can_see_voters(user, poll)
    users = {u.id: u for u in User.objects.filter(pk__in={uid for q in answers.values() for uid in q})} \
        if voters_visible else None
    closed = rules.is_closed(poll)
    reveal = poll.kind == Poll.QUIZ and (closed or poll.creator_id == user.id)
    questions = [_question_result(q, answers[q.id], users, reveal) for q in poll.questions.order_by("rank", "id")]
    scores = my_score = max_score = None
    if poll.kind == Poll.QUIZ:
        max_score, totals = _max_score(poll), scores_by_user(poll, answers)
        my_score = totals.get(user.id) if closed else None
        if poll.creator_id == user.id and poll.anonymity != Poll.ANON_ALL:
            people = {u.id: u for u in User.objects.filter(pk__in=totals)}
            scores = [ScoreOut(user=user_ref(people[uid]), score=s, max_score=max_score)
                      for uid, s in sorted(totals.items())]
    return ResultsOut(poll_id=poll.id, kind=poll.kind, status="closed" if closed else "open",
                      participants=poll.submissions.count(), questions=questions, scores=scores,
                      my_score=my_score, max_score=max_score)


def export(user: User, poll_id: UUID) -> ExportOut:
    """Rows for printing: creator and target moderators only; voter names only when the anonymity allows."""
    poll = _load(user, poll_id)
    if not rules.can_moderate(user, poll):
        raise HttpError(403, "Permission denied")
    data = results(user, poll_id)
    rows = []
    for q in data.questions:
        for o in q.options:
            correct = (o.id in q.correct_option_ids) if q.correct_option_ids is not None else None
            names = [v.full_name or v.email for v in o.voters] if o.voters is not None else None
            rows.append(ExportRow(question=q.text, option=o.text, count=o.count, correct=correct, voters=names))
    scores = [{"participant": s.user.full_name or s.user.email, "score": s.score, "max_score": s.max_score}
              for s in data.scores] if data.scores is not None else None
    return ExportOut(title=poll.title, kind=poll.kind, status=data.status, participants=data.participants,
                     rows=rows, scores=scores)
