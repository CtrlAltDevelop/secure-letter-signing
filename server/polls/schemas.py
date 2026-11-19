from datetime import datetime
from typing import Any
from uuid import UUID

from ninja import Field, Schema

from workspace.schemas import UserRef

KIND = "^(poll|quiz)$"
ANONYMITY = "^(public|anonymous_to_users|anonymous_to_all)$"
MAX_QUESTIONS, MAX_OPTIONS = 50, 20


class QuestionIn(Schema):
    text: str = Field(min_length=1, max_length=500)
    multiple: bool = False
    options: list[str] = Field(min_length=2, max_length=MAX_OPTIONS)
    correct: list[int] = Field(default_factory=list, max_length=MAX_OPTIONS)  # quiz: indexes into `options`
    points: int = Field(1, ge=1, le=100)


class PollIn(Schema):
    target_subject_id: UUID
    title: str | None = Field(None, min_length=1, max_length=200)
    kind: str | None = Field(None, pattern=KIND)
    anonymity: str | None = Field(None, pattern=ANONYMITY)
    closes_at: datetime | None = None
    questions: list[QuestionIn] | None = Field(None, max_length=MAX_QUESTIONS)
    template_id: int | None = None


class AnswerIn(Schema):
    question_id: int
    option_ids: list[int] = Field(max_length=MAX_OPTIONS)


class SubmitIn(Schema):
    answers: list[AnswerIn] = Field(max_length=MAX_QUESTIONS)


class TemplateData(Schema):
    title: str = Field("", max_length=200)
    kind: str = Field("poll", pattern=KIND)
    anonymity: str = Field("public", pattern=ANONYMITY)
    questions: list[QuestionIn] = Field(default_factory=list, max_length=MAX_QUESTIONS)


class TemplateIn(Schema):
    name: str = Field(min_length=1, max_length=100)
    scope: str = Field("personal", pattern="^(org|personal)$")
    data: TemplateData


class TemplatePatch(Schema):
    name: str | None = Field(None, min_length=1, max_length=100)
    data: TemplateData | None = None
    active: bool | None = None


class TemplateOut(Schema):
    id: int
    name: str
    scope: str
    owner_id: int | None
    data: dict[str, Any]
    active: bool


class OptionOut(Schema):
    id: int
    text: str


class QuestionOut(Schema):
    id: int
    text: str
    multiple: bool
    points: int
    options: list[OptionOut]
    correct_option_ids: list[int] | None  # creator always; everybody else once the poll is closed (quiz only)


class CanOut(Schema):
    submit: bool
    close: bool
    results: bool
    see_voters: bool


class PollBrief(Schema):
    id: UUID
    subject_id: UUID
    target_subject_id: UUID
    title: str
    kind: str
    anonymity: str
    status: str  # open | closed
    closes_at: datetime | None
    closed_at: datetime | None
    creator: UserRef
    question_count: int
    participants: int
    i_submitted: bool
    created_at: datetime


class PollOut(PollBrief):
    questions: list[QuestionOut]
    my_answers: dict[int, list[int]]
    can: CanOut


class OptionResult(Schema):
    id: int
    text: str
    count: int
    voters: list[UserRef] | None  # None when voters are hidden from the caller


class QuestionResult(Schema):
    id: int
    text: str
    multiple: bool
    points: int
    options: list[OptionResult]
    correct_option_ids: list[int] | None


class ScoreOut(Schema):
    user: UserRef
    score: int
    max_score: int


class ResultsOut(Schema):
    poll_id: UUID
    kind: str
    status: str
    participants: int
    questions: list[QuestionResult]
    scores: list[ScoreOut] | None  # quiz: per participant, creator only and never for anonymous_to_all
    my_score: int | None  # quiz: the caller's own score once the poll is closed
    max_score: int | None


class ExportRow(Schema):
    question: str
    option: str
    count: int
    correct: bool | None
    voters: list[str] | None


class ExportOut(Schema):
    title: str
    kind: str
    status: str
    participants: int
    rows: list[ExportRow]
    scores: list[dict[str, Any]] | None
