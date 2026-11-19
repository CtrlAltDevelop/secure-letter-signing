"""Guest users: external collaborators with no default grants, restricted to tasks, projects and chat.

Everything a guest sees still flows through membership rows (project/conversation members); they are never listed in
the directory for people they share nothing with, and they see only people they share a project or conversation with.
"""
from django.db.models import Q
from django.utils import timezone

from .models import User

GUEST_MODULES = frozenset({"tasks", "projects", "chat"})


def is_expired(user: User) -> bool:
    return bool(user.is_guest and user.guest_expires_at and user.guest_expires_at <= timezone.now())


def shared_user_ids(user: User) -> set[int]:
    """Ids of people who share an active project or a (non-DM or DM) conversation with `user`."""
    from chat.models import ConversationMember
    from projects.models import ProjectMember

    projects = ProjectMember.objects.filter(user=user, active=True).values("project_id")
    convs = ConversationMember.objects.filter(user=user, active=True).values("conversation_id")
    ids = set(ProjectMember.objects.filter(project_id__in=projects, active=True).values_list("user_id", flat=True))
    ids |= set(ConversationMember.objects.filter(conversation_id__in=convs, active=True).values_list("user_id", flat=True))
    ids.discard(user.id)
    return ids


def visible_users(viewer: User, qs=None):
    """`qs` (default: active users) limited to what `viewer` may see: a guest sees only people they share a project or
    conversation with, everybody else sees no guests except those they share one with."""
    qs = User.objects.filter(is_active=True) if qs is None else qs
    shared = shared_user_ids(viewer)
    if viewer.is_guest:
        return qs.filter(Q(pk__in=shared) | Q(pk=viewer.pk))
    return qs.filter(Q(is_guest=False) | Q(pk__in=shared) | Q(pk=viewer.pk))


def referable_ids(actor: User, ids) -> set[int]:
    """The subset of `ids` that `actor` may put on a roster: the company manager, any non-guest actor for non-guests,
    and for guests only people the actor already shares something with (or the actor)."""
    ids = set(ids)
    if actor.is_manager:
        return ids
    guests = set(User.objects.filter(pk__in=ids, is_guest=True).values_list("pk", flat=True))
    if not guests and not actor.is_guest:
        return ids
    allowed = shared_user_ids(actor) | {actor.id}
    if actor.is_guest:
        return ids & allowed
    return ids - (guests - allowed)
