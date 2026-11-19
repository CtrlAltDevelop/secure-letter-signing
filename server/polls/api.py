"""Polls API (mounted at /api/polls). Access derives from the target subject (see rules.py)."""
from uuid import UUID

from django.shortcuts import get_object_or_404
from ninja import Router
from ninja.errors import HttpError

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, user_of
from accounts.models import User
from workspace import registry
from workspace.schemas import user_ref

from . import results, rules, service
from .models import Poll, PollAnswer, PollSubmission
from .schemas import (CanOut, ExportOut, OptionOut, PollBrief, PollIn, PollOut, QuestionOut, ResultsOut, SubmitIn)

router = Router(tags=["polls"], auth=BearerAuth())
ERRORS = {403: Detail, 404: Detail, 409: Detail, 422: Detail}
MAX_LIMIT, SCAN_LIMIT = 200, 1000


def _gate() -> None:
    registry.require_module("polls")


def _status(poll: Poll) -> str:
    return "closed" if rules.is_closed(poll) else "open"


def brief(user: User, poll: Poll) -> PollBrief:
    return PollBrief(
        id=poll.id, subject_id=poll.subject_id, target_subject_id=poll.target_subject_id, title=poll.title,
        kind=poll.kind, anonymity=poll.anonymity, status=_status(poll), closes_at=poll.closes_at,
        closed_at=poll.closed_at, creator=user_ref(poll.creator), question_count=poll.questions.count(),
        participants=poll.submissions.count(), i_submitted=PollSubmission.objects.filter(poll=poll, user=user).exists(),
        created_at=poll.created_at)


def poll_out(user: User, poll: Poll) -> PollOut:
    closed, mine = rules.is_closed(poll), poll.creator_id == user.id
    questions = [QuestionOut(
        id=q.id, text=q.text, multiple=q.multiple, points=q.points,
        options=[OptionOut(id=o.id, text=o.text) for o in q.options.order_by("rank", "id")],
        correct_option_ids=q.correct_option_ids if poll.kind == Poll.QUIZ and (closed or mine) else None)
        for q in poll.questions.order_by("rank", "id")]
    answers: dict[int, list[int]] = {}
    for qid, oid in PollAnswer.objects.filter(question__poll=poll, user=user, active=True).values_list(
            "question_id", "option_id"):
        answers.setdefault(qid, []).append(oid)
    return PollOut(**brief(user, poll).model_dump(), questions=questions, my_answers=answers, can=CanOut(
        submit=not closed and rules.can_participate(user, poll), close=poll.closed_at is None and rules.can_moderate(user, poll),
        results=results.can_see_results(user, poll), see_voters=rules.can_see_voters(user, poll)))


def _visible(user: User, poll_id: UUID) -> Poll:
    poll = get_object_or_404(Poll.objects.select_related("target_subject", "creator", "subject"), pk=poll_id)
    if not rules.can_see(user, poll):
        raise HttpError(404, "Not found")
    return poll


@router.post("", response={201: PollOut, **ERRORS})
def create(request, data: PollIn):
    _gate()
    user = user_of(request)
    return 201, poll_out(user, service.create_poll(user, data))


@router.get("", response=list[PollBrief])
def list_polls(request, target_subject: UUID | None = None, mine: bool = False, status: str = "", limit: int = 50,
               offset: int = 0):
    _gate()
    user = user_of(request)
    rows = Poll.objects.select_related("target_subject", "creator").order_by("-created_at", "-id")
    if target_subject:
        rows = rows.filter(target_subject_id=target_subject)
    if mine:
        rows = rows.filter(creator=user)
    visible = [p for p in rows[:SCAN_LIMIT] if rules.can_see(user, p)]
    if status in ("open", "closed"):
        visible = [p for p in visible if _status(p) == status]
    start = max(offset, 0)
    return [brief(user, p) for p in visible[start : start + max(min(limit, MAX_LIMIT), 0)]]


@router.get("/{uuid:poll_id}", response={200: PollOut, 404: Detail})
def get_poll(request, poll_id: UUID):
    _gate()
    user = user_of(request)
    return poll_out(user, _visible(user, poll_id))


@router.post("/{uuid:poll_id}/submit", response={200: PollOut, **ERRORS})
def submit(request, poll_id: UUID, data: SubmitIn):
    _gate()
    user = user_of(request)
    return poll_out(user, service.submit(user, poll_id, data))


@router.post("/{uuid:poll_id}/close", response={200: PollOut, **ERRORS})
def close(request, poll_id: UUID):
    _gate()
    user = user_of(request)
    return poll_out(user, service.close(user, poll_id))


@router.get("/{uuid:poll_id}/results", response={200: ResultsOut, **ERRORS})
def get_results(request, poll_id: UUID):
    _gate()
    return results.results(user_of(request), poll_id)


@router.get("/{uuid:poll_id}/results/export", response={200: ExportOut, **ERRORS})
def export_results(request, poll_id: UUID):
    _gate()
    return results.export(user_of(request), poll_id)
