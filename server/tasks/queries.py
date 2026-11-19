"""Task lists: what each user sees and the inbox / follow-up boxes."""
from datetime import datetime
from uuid import UUID

from django.db.models import Exists, F, OuterRef, Q, QuerySet

from accounts.models import User
from workspace.access import visible_labels
from projects.models import ProjectMember
from workspace.models import SubjectLabel

from .models import Task, TaskPerson

MAX_LIMIT = 200
STATUS_VALUES = {Task.OPEN, Task.AWAITING, Task.DONE, Task.CANCELLED}


def visible_tasks(user: User) -> QuerySet[Task]:
    """Personal tasks: creator and active people. Project tasks: every active member of the project."""
    involved = Q(creator=user) | Q(Exists(TaskPerson.objects.filter(task=OuterRef("pk"), user=user, active=True)))
    member = Exists(ProjectMember.objects.filter(project=OuterRef("project_id"), user=user, active=True))
    return Task.objects.filter(Q(project__isnull=True) & involved | Q(project__isnull=False) & Q(member))


def _is_owner(user: User) -> Exists:
    return Exists(TaskPerson.objects.filter(task=OuterRef("pk"), user=user, role=TaskPerson.OWNER, active=True))


def _current_approver_of(user: User) -> Exists:
    """Awaiting tasks where `user` is the first approver (by position) who has not decided yet."""
    earlier = TaskPerson.objects.filter(task=OuterRef("task"), role=TaskPerson.APPROVER, active=True, decision="",
                                        position__lt=OuterRef("position"))
    mine = TaskPerson.objects.filter(task=OuterRef("pk"), user=user, role=TaskPerson.APPROVER, active=True,
                                     decision="").annotate(earlier=Exists(earlier)).filter(earlier=False)
    return Exists(mine)


def _is_follower(user: User) -> Exists:
    return Exists(TaskPerson.objects.filter(task=OuterRef("pk"), user=user, role=TaskPerson.FOLLOWER, active=True))


def box_of(user: User, rows: QuerySet[Task], box: str) -> QuerySet[Task]:
    if box == "inbox":
        mine = Q(status=Task.OPEN) & Q(_is_owner(user)) | Q(status=Task.AWAITING) & Q(_current_approver_of(user))
        return rows.filter(mine)
    if box == "followup":
        return rows.filter(Q(creator=user) | Q(_is_follower(user))).exclude(_is_owner(user))
    return rows


def _managed_projects(user: User) -> QuerySet[ProjectMember]:
    return ProjectMember.objects.filter(user=user, active=True, role=ProjectMember.MANAGER).values("project_id")


def filtered(user: User, box: str, status: str, q: str, label: int | None, due_before: datetime | None,
             customer: UUID | None = None, include_hidden: bool = False) -> QuerySet[Task]:
    rows = box_of(user, Task.objects.filter(pk__in=visible_tasks(user).values("pk")), box)
    if include_hidden:  # removed tasks are shown to the managers of their project only
        rows = rows.filter(Q(hidden=False) | Q(project_id__in=_managed_projects(user)))
    else:
        rows = rows.filter(hidden=False)
    wanted = {s for s in status.split(",") if s}
    if wanted:
        rows = rows.filter(status__in=wanted & STATUS_VALUES)
    if q.strip():
        rows = rows.filter(title__icontains=q.strip())
    if label is not None:
        ok = visible_labels(user).filter(pk=label, active=True).exists()
        subjects = SubjectLabel.objects.filter(label_id=label, active=True).values("subject_id") if ok else []
        rows = rows.filter(subject_id__in=subjects)
    if due_before is not None:
        rows = rows.filter(due_at__lt=due_before)
    if customer is not None:
        rows = rows.filter(customer_id=customer)
    if box == "inbox":
        return rows.order_by(F("due_at").asc(nulls_last=True), "-updated_at", "id")
    return rows.order_by("-updated_at", "id")
