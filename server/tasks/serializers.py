"""Task -> TaskBrief / TaskOut, with the related rows loaded in a fixed number of queries."""
from collections import defaultdict
from collections.abc import Sequence

from django.db.models import Count, Q

from accounts.models import User
from crm import membership as crm_membership
from workspace.models import Comment, File, Label, SeenBy, SubjectLabel
from workspace.schemas import user_ref
from workspace.textbox import open_text

from . import removal, rules
from .models import Task, TaskPerson
from .schemas import (ApproverOut, CanOut, ChecklistCount, ChecklistItemOut, DescriptionOut, TaskBrief, TaskOut)
from .store import active_items


def _roles(user: User, task: Task, people: list[TaskPerson]) -> list[str]:
    roles = {p.role for p in people if p.user_id == user.id}
    if task.creator_id == user.id:
        roles.add(rules.CREATOR)
    return sorted(roles)


def _label_map(user: User, tasks: Sequence[Task]) -> dict:
    rows = (SubjectLabel.objects.filter(subject_id__in=[t.subject_id for t in tasks], active=True, label__active=True)
            .filter(Q(label__scope=Label.ORG) | Q(label__owner=user)).values_list("subject_id", "label_id"))
    out: dict = defaultdict(list)
    for subject_id, label_id in rows:
        out[subject_id].append(label_id)
    return out


def _checklist_map(tasks: Sequence[Task]) -> dict[object, ChecklistCount]:
    from .models import ChecklistItem

    rows = (ChecklistItem.objects.filter(task__in=tasks, active=True).values("task_id")
            .annotate(total=Count("id"), done=Count("id", filter=Q(done=True))))
    return {r["task_id"]: ChecklistCount(done=r["done"], total=r["total"]) for r in rows}


def briefs(user: User, tasks: Sequence[Task]) -> list[TaskBrief]:
    people: dict = defaultdict(list)
    for p in TaskPerson.objects.filter(task__in=tasks, active=True):
        people[p.task_id].append(p)
    labels, counts = _label_map(user, tasks), _checklist_map(tasks)
    customers = crm_membership.visible_names(user, [t.customer_id for t in tasks])
    seen = dict(SeenBy.objects.filter(user=user, subject_id__in=[t.subject_id for t in tasks])
                .values_list("subject_id", "last_at"))
    out = []
    for t in tasks:
        rows = people[t.id]
        last_seen = seen.get(t.subject_id)
        out.append(TaskBrief(
            id=t.id, subject_id=t.subject_id, title=t.title, status=t.status, priority=t.priority,
            progress=t.progress, due_at=t.due_at, all_day=t.all_day, weight=t.weight, hidden=t.hidden,
            project_id=t.project_id,
            column_id=t.column_id, rank=t.rank, customer_id=t.customer_id if t.customer_id in customers else None,
            customer_name=customers.get(t.customer_id),
            owner_ids=sorted(p.user_id for p in rows if p.role == TaskPerson.OWNER),
            my_roles=_roles(user, t, rows), label_ids=sorted(labels[t.subject_id]),
            checklist=counts.get(t.id, ChecklistCount(done=0, total=0)),
            unseen=last_seen is None or t.updated_at > last_seen, updated_at=t.updated_at))
    return out


def task_out(user: User, task: Task) -> TaskOut:
    brief = briefs(user, [task])[0]
    people = list(TaskPerson.objects.filter(task=task, active=True).select_related("user").order_by("position", "id"))
    by_role = lambda role: [p for p in people if p.role == role]  # noqa: E731
    items = active_items(task).select_related("done_by").order_by("rank", "id")
    return TaskOut(
        **brief.model_dump(),
        description=DescriptionOut(text=open_text(task.description)),
        creator=user_ref(task.creator),
        owners=[user_ref(p.user) for p in by_role(TaskPerson.OWNER)],
        approvers=[ApproverOut(user=user_ref(p.user), position=p.position, decision=p.decision, decided_at=p.decided_at)
                   for p in by_role(TaskPerson.APPROVER)],
        followers=[user_ref(p.user) for p in by_role(TaskPerson.FOLLOWER)],
        checklist_items=[ChecklistItemOut(id=i.id, text=i.text, done=i.done, done_at=i.done_at,
                                          done_by=user_ref(i.done_by) if i.done_by else None) for i in items],
        start_at=task.start_at, progress_mode=task.progress_mode, version=task.version,
        completed_at=task.completed_at, created_at=task.created_at,
        can=CanOut(**{a: rules.can(user, task, a) for a in ("move", "edit", "progress", "approve", "comment", "complete",
                                                              "reopen", "request_removal", "decide_removal")}),
        removal=removal.latest_out(task),
        comment_count=Comment.objects.filter(subject_id=task.subject_id, active=True).count(),
        file_count=File.objects.filter(subject_id=task.subject_id, active=True).count())
