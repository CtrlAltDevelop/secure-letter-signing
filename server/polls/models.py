"""Polls and quizzes attached to any workspace subject. Nothing is deleted (answers are replaced by deactivation)."""
import uuid

from django.conf import settings
from django.db import models
from django.utils import timezone

User = settings.AUTH_USER_MODEL


class PollTemplate(models.Model):
    """`owner` null = organisation template (manager only). `data` = {title, kind, anonymity, questions:[...]}."""

    owner = models.ForeignKey(User, null=True, blank=True, on_delete=models.PROTECT, related_name="+")
    name = models.CharField(max_length=100)
    data = models.JSONField(default=dict)
    active = models.BooleanField(default=True)
    created_at = models.DateTimeField(default=timezone.now)


class Poll(models.Model):
    POLL, QUIZ = "poll", "quiz"
    KINDS = [(POLL, POLL), (QUIZ, QUIZ)]
    PUBLIC, ANON_USERS, ANON_ALL = "public", "anonymous_to_users", "anonymous_to_all"
    ANONYMITY = [(a, a) for a in (PUBLIC, ANON_USERS, ANON_ALL)]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    subject = models.OneToOneField("workspace.Subject", on_delete=models.PROTECT, related_name="poll")
    target_subject = models.ForeignKey("workspace.Subject", on_delete=models.PROTECT, related_name="target_polls")
    creator = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    title = models.CharField(max_length=200)
    kind = models.CharField(max_length=10, choices=KINDS, default=POLL)
    anonymity = models.CharField(max_length=20, choices=ANONYMITY, default=PUBLIC)
    closes_at = models.DateTimeField(null=True, blank=True)
    closed_at = models.DateTimeField(null=True, blank=True)
    closed_by = models.ForeignKey(User, null=True, blank=True, on_delete=models.PROTECT, related_name="+")
    template = models.ForeignKey(PollTemplate, null=True, blank=True, on_delete=models.PROTECT, related_name="+")
    created_at = models.DateTimeField(default=timezone.now)


class PollQuestion(models.Model):
    poll = models.ForeignKey(Poll, on_delete=models.PROTECT, related_name="questions")
    text = models.CharField(max_length=500)
    multiple = models.BooleanField(default=False)
    rank = models.PositiveIntegerField(default=0)
    correct_option_ids = models.JSONField(default=list, blank=True)  # quiz only
    points = models.PositiveSmallIntegerField(default=1)


class PollOption(models.Model):
    question = models.ForeignKey(PollQuestion, on_delete=models.PROTECT, related_name="options")
    text = models.CharField(max_length=300)
    rank = models.PositiveIntegerField(default=0)


class PollSubmission(models.Model):
    """One per user per poll; re-submitting while the poll is open replaces the active answers."""

    poll = models.ForeignKey(Poll, on_delete=models.PROTECT, related_name="submissions")
    user = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    submitted_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(default=timezone.now)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["poll", "user"], name="one_submission_per_user_poll")]


class PollAnswer(models.Model):
    question = models.ForeignKey(PollQuestion, on_delete=models.PROTECT, related_name="answers")
    user = models.ForeignKey(User, on_delete=models.PROTECT, related_name="+")
    option = models.ForeignKey(PollOption, on_delete=models.PROTECT, related_name="answers")
    active = models.BooleanField(default=True)  # replaced answers are deactivated, never deleted
    created_at = models.DateTimeField(default=timezone.now)
