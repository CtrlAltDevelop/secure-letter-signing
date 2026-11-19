"""Who may do what with a poll. Everything derives from the poll's target subject and its own module's rules."""
from django.utils import timezone

from accounts.models import User
from workspace import registry
from workspace.models import Subject

from .models import Poll


def target_can(user: User, target: Subject, action: str) -> bool:
    """Ask the target's module (False when the module is off or the target is gone)."""
    if target.module not in registry.enabled_modules():
        return False
    spec = registry.get(target.module)
    obj = spec.resolve(target) if spec else None
    return obj is not None and spec.can(user, obj, "see") and spec.can(user, obj, action)


def target_audience(target: Subject) -> set[int]:
    spec = registry.get(target.module)
    obj = spec.resolve(target) if spec else None
    return set(spec.audience(obj)) if obj is not None and spec.audience else set()


def is_closed(poll: Poll) -> bool:
    return poll.closed_at is not None or (poll.closes_at is not None and poll.closes_at <= timezone.now())


def can_moderate(user: User, poll: Poll) -> bool:
    """The creator, or someone who may moderate the target (its manager)."""
    return poll.creator_id == user.id or target_can(user, poll.target_subject, "moderate")


def can_see(user: User, poll: Poll) -> bool:
    return target_can(user, poll.target_subject, "see")


def can_participate(user: User, poll: Poll) -> bool:
    return target_can(user, poll.target_subject, "comment")


def can_see_voters(user: User, poll: Poll) -> bool:
    if poll.anonymity == Poll.PUBLIC:
        return True
    return poll.anonymity == Poll.ANON_USERS and can_moderate(user, poll)


def can(user: User, poll: Poll, action: str) -> bool:
    if action in ("see", "label"):
        return can_see(user, poll)
    if action == "comment":
        return can_participate(user, poll)
    if action == "moderate":
        return can_see(user, poll) and can_moderate(user, poll)
    return False


def audience(poll: Poll) -> set[int]:
    return target_audience(poll.target_subject) | {poll.creator_id}
