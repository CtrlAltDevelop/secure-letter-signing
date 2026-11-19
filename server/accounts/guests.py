"""Guest users: external collaborators with no default grants, restricted to tasks, projects and chat.

Everything a guest sees still flows through membership rows (project/conversation members); they are never listed in
the directory for people they share nothing with, and they see only people they share a project or conversation with.
"""
from django.db.models import Q
from django.utils import timezone

from .models import User

GUEST_MODULES = frozenset({"tasks", "projects", "chat"})


def create_guest(email: str, password: str, full_name: str = "", expires_at=None) -> User:
    """A guest account: only the base grant, never the default grants."""
    from .models import BASE_PERMISSION, Permission

    user = User.objects.create_user(email, password, full_name=full_name, is_guest=True, guest_expires_at=expires_at,
                                    is_active=True)
    user.grants.add(*Permission.objects.filter(code=BASE_PERMISSION))
    return user


# First path segment (after /api/) -> the module that owns it, for the modules guests may not use.
PATH_MODULES = {
    "letters": "letters", "sign-requests": "letters", "referrals": "letters", "secretariat": "letters",
    "customers": "crm", "finance": "finance", "sales": "sales", "meetings": "meetings",
    "meeting-templates": "meetings", "notes": "notes", "polls": "polls", "poll-templates": "polls",
    "manage": "manage",
}


def refuses_path(user: User, path: str) -> bool:
    """True when `user` is a guest asking for a module's endpoints (answered 404, like a switched-off module)."""
    if not user.is_guest:
        return False
    parts = path.strip("/").split("/")
    module = PATH_MODULES.get(parts[1] if len(parts) > 1 and parts[0] == "api" else "")
    return module is not None and module not in GUEST_MODULES


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
