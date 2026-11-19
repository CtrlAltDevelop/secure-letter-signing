"""Create polls (optionally from a template), submit answers, close. Audit rows carry ids only, never answers."""
from uuid import UUID

from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja.errors import HttpError

from accounts.models import User, audit
from workspace.events import emit
from workspace.models import Subject

from . import rules, templates
from .models import Poll, PollAnswer, PollOption, PollQuestion, PollSubmission
from .schemas import PollIn, QuestionIn, SubmitIn

MODULE = "polls"


def _check_question(kind: str, q: QuestionIn) -> None:
    options = [o.strip() for o in q.options]
    if not all(options):
        raise HttpError(422, "Options cannot be empty")
    if kind == Poll.POLL:
        if q.correct:
            raise HttpError(422, "Only quizzes have correct answers")
        return
    if not q.correct or any(not 0 <= i < len(options) for i in q.correct) or len(set(q.correct)) != len(q.correct):
        raise HttpError(422, "A quiz question needs valid correct options")
    if not q.multiple and len(q.correct) != 1:
        raise HttpError(422, "A single-choice question has exactly one correct option")


def _make_questions(poll: Poll, questions: list[QuestionIn]) -> None:
    for rank, q in enumerate(questions):
        question = PollQuestion.objects.create(poll=poll, text=q.text.strip(), multiple=q.multiple, rank=rank,
                                               points=q.points if poll.kind == Poll.QUIZ else 1)
        options = [PollOption.objects.create(question=question, text=t.strip(), rank=i)
                   for i, t in enumerate(q.options)]
        if q.correct:
            question.correct_option_ids = [options[i].id for i in q.correct]
            question.save(update_fields=["correct_option_ids"])


def _resolved(data: PollIn, template) -> dict:
    base = template.data if template else {}
    questions = data.questions
    if questions is None:
        questions = [QuestionIn(**q) for q in base.get("questions", [])]
    return {"title": (data.title or base.get("title") or (template.name if template else "")).strip(),
            "kind": data.kind or base.get("kind", Poll.POLL),
            "anonymity": data.anonymity or base.get("anonymity", Poll.PUBLIC), "questions": questions}


@transaction.atomic
def create_poll(user: User, data: PollIn) -> Poll:
    target = get_object_or_404(Subject, pk=data.target_subject_id)
    if not rules.target_can(user, target, "see"):
        raise HttpError(404, "Not found")
    if not rules.target_can(user, target, "comment"):
        raise HttpError(403, "Permission denied")
    template = templates.usable(user, data.template_id) if data.template_id else None
    values = _resolved(data, template)
    if not values["title"]:
        raise HttpError(422, "A title is required")
    if not values["questions"]:
        raise HttpError(422, "A poll needs at least one question")
    if data.closes_at and data.closes_at <= timezone.now():
        raise HttpError(422, "closes_at must be in the future")
    for q in values["questions"]:
        _check_question(values["kind"], q)
    subject = Subject.objects.create(module=MODULE, kind="poll")
    poll = Poll.objects.create(subject=subject, target_subject=target, creator=user, title=values["title"],
                               kind=values["kind"], anonymity=values["anonymity"], closes_at=data.closes_at,
                               template=template)
    _make_questions(poll, values["questions"])
    audit(user, "poll_created", str(poll.id), kind=poll.kind, anonymity=poll.anonymity)
    emit(MODULE, "poll.created", subject, poll.title, user, rules.audience(poll) - {user.id},
         object_id=str(poll.id), target_subject_id=str(target.id))
    return poll


def _validated_answers(poll: Poll, data: SubmitIn) -> dict[int, list[int]]:
    questions = {q.id: q for q in poll.questions.all()}
    chosen: dict[int, list[int]] = {}
    for a in data.answers:
        if a.question_id not in questions or a.question_id in chosen:
            raise HttpError(422, "Unknown or repeated question")
        chosen[a.question_id] = list(dict.fromkeys(a.option_ids))
    if set(chosen) != set(questions):
        raise HttpError(422, "Every question needs an answer")
    for qid, ids in chosen.items():
        valid = set(PollOption.objects.filter(question_id=qid).values_list("id", flat=True))
        if not ids or not set(ids) <= valid or (not questions[qid].multiple and len(ids) != 1):
            raise HttpError(422, "Invalid options for a question")
    return chosen


@transaction.atomic
def submit(user: User, poll_id: UUID, data: SubmitIn) -> Poll:
    poll = get_object_or_404(Poll.objects.select_for_update(of=("self",)).select_related("target_subject"), pk=poll_id)
    if not rules.can_see(user, poll):
        raise HttpError(404, "Not found")
    if not rules.can_participate(user, poll):
        raise HttpError(403, "Permission denied")
    if rules.is_closed(poll):
        raise HttpError(409, "The poll is closed")
    chosen = _validated_answers(poll, data)
    now = timezone.now()
    sub, created = PollSubmission.objects.get_or_create(poll=poll, user=user)
    if not created:
        PollAnswer.objects.filter(question__poll=poll, user=user, active=True).update(active=False)
        sub.updated_at = now
        sub.save(update_fields=["updated_at"])
    PollAnswer.objects.bulk_create([PollAnswer(question_id=qid, user=user, option_id=oid)
                                    for qid, ids in chosen.items() for oid in ids])
    return poll


@transaction.atomic
def close(user: User, poll_id: UUID) -> Poll:
    poll = get_object_or_404(Poll.objects.select_for_update(of=("self",)).select_related("target_subject", "subject"),
                             pk=poll_id)
    if not rules.can_see(user, poll):
        raise HttpError(404, "Not found")
    if not rules.can_moderate(user, poll):
        raise HttpError(403, "Permission denied")
    if poll.closed_at is not None:
        raise HttpError(409, "The poll is already closed")
    poll.closed_at, poll.closed_by = timezone.now(), user
    poll.save(update_fields=["closed_at", "closed_by"])
    audit(user, "poll_closed", str(poll.id))
    emit(MODULE, "poll.closed", poll.subject, poll.title, user, rules.audience(poll) - {user.id},
         object_id=str(poll.id), target_subject_id=str(poll.target_subject_id))
    return poll
