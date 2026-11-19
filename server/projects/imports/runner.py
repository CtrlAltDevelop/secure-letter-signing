"""Create the tasks of a parsed import inside a project (manager only, one transaction, one summary event)."""
from dataclasses import dataclass, field
from uuid import UUID

from django.db import transaction
from ninja import Schema
from ninja.errors import HttpError

from accounts.models import User, audit
from projects import membership, notices, progress, service
from projects.models import BoardColumn, Project
from tasks import history
from tasks.models import ChecklistItem, Task, TaskPerson
from tasks.placement import default_column
from tasks.store import RANK_GAP
from workspace.access import visible_labels
from workspace.models import Label, Subject, SubjectLabel
from workspace.textbox import seal_text

from . import tabular, trello
from .model import MAX_BYTES, MAX_LABEL, Draft, Parsed

FORMATS = ("trello", "csv", "xlsx")


class ImportOut(Schema):
    created: int
    skipped: int
    errors: list[dict]
    warnings: list[dict]


@dataclass
class Context:
    """Lookups shared by all rows of one import; missing columns and labels are created on first use."""

    user: User
    project: Project
    columns: dict[str, BoardColumn]
    members: dict[str, int]
    labels: dict[str, int]
    next_rank: dict[int, int] = field(default_factory=dict)
    missing_labels: set[str] = field(default_factory=set)


def _member_lookup(project: Project) -> dict[str, int]:
    """Lower-case email and email-local-part ('username') -> user id; ambiguous usernames are dropped."""
    found: dict[str, int] = {}
    ambiguous: set[str] = set()
    for pk, email in User.objects.filter(pk__in=membership.member_ids(project.pk)).values_list("pk", "email"):
        found[email.lower()] = pk
        local = email.split("@")[0].lower()
        if local in found and found[local] != pk:
            ambiguous.add(local)
        found.setdefault(local, pk)
    return {k: v for k, v in found.items() if k not in ambiguous}


def _context(user: User, project: Project) -> Context:
    columns = {c.title.lower(): c for c in BoardColumn.objects.filter(project=project, active=True)}
    labels = {lb.name.lower(): lb.pk for lb in visible_labels(user).filter(active=True)}
    return Context(user, project, columns, _member_lookup(project), labels)


def _column_for(ctx: Context, name: str | None) -> BoardColumn:
    if not name:
        return default_column(ctx.project)
    column = ctx.columns.get(name.lower())
    if column is None:
        last = BoardColumn.objects.filter(project=ctx.project).order_by("-rank").first()
        column = BoardColumn.objects.create(project=ctx.project, title=name, kind=BoardColumn.DOING,
                                            rank=(last.rank if last else 0) + service.RANK_GAP)
        ctx.columns[name.lower()] = column
    return column


def _rank_in(ctx: Context, column: BoardColumn) -> int:
    if column.pk not in ctx.next_rank:
        last = Task.objects.filter(column=column).order_by("-rank").first()
        ctx.next_rank[column.pk] = last.rank if last else 0
    ctx.next_rank[column.pk] += RANK_GAP
    return ctx.next_rank[column.pk]


def _owners(ctx: Context, draft: Draft, parsed: Parsed) -> list[int]:
    ids = []
    for ref in draft.owner_refs:
        found = ctx.members.get(ref.lower())
        if found is None:
            parsed.warn(draft.row, "A person was not found among the project members and was skipped")
        elif found not in ids:
            ids.append(found)
    return ids or [ctx.user.id]


def _label_ids(ctx: Context, draft: Draft, parsed: Parsed) -> list[int]:
    """Existing visible labels by name; new ones only as organisation labels, and only for the company manager."""
    ids = []
    for name in dict.fromkeys(draft.labels):
        key = name.lower()
        if key not in ctx.labels and ctx.user.is_manager:
            ctx.labels[key] = Label.objects.create(scope=Label.ORG, name=name[:MAX_LABEL]).pk
        if key in ctx.labels:
            ids.append(ctx.labels[key])
        elif key not in ctx.missing_labels:
            ctx.missing_labels.add(key)
            parsed.warn(draft.row, "A label does not exist and only the company manager can create it; skipped")
    return ids


def _create(ctx: Context, draft: Draft, parsed: Parsed) -> None:
    column = _column_for(ctx, draft.column)
    owners = _owners(ctx, draft, parsed)
    subject = Subject.objects.create(module="tasks", kind="task")
    task = Task.objects.create(
        subject=subject, project=ctx.project, column=column, rank=_rank_in(ctx, column), title=draft.title,
        description=seal_text(draft.description), creator=ctx.user, priority=draft.priority, due_at=draft.due_at,
        all_day=draft.all_day, status=Task.CANCELLED if draft.closed else Task.OPEN)
    TaskPerson.objects.bulk_create([TaskPerson(task=task, user_id=u, role=TaskPerson.OWNER) for u in owners])
    ChecklistItem.objects.bulk_create([
        ChecklistItem(task=task, text=text, done=done, rank=(i + 1) * RANK_GAP,
                      done_by=ctx.user if done else None) for i, (text, done) in enumerate(draft.checklist)])
    SubjectLabel.objects.bulk_create([SubjectLabel(subject=subject, label_id=i, added_by=ctx.user)
                                      for i in _label_ids(ctx, draft, parsed)])
    history.log(subject, ctx.user, "status", None, task.status)


def parse_upload(fmt: str, data: bytes) -> Parsed:
    if fmt not in FORMATS:
        raise HttpError(422, "format must be trello, csv or xlsx")
    if len(data) > MAX_BYTES:
        raise HttpError(413, "The file is larger than 5 MB")
    return trello.parse(data) if fmt == "trello" else tabular.parse(data, fmt)


@transaction.atomic
def import_into_project(user: User, project_id: UUID, fmt: str, data: bytes) -> ImportOut:
    service.gate()
    project = service.lock_project(user, project_id, "edit")
    if project.status == Project.ARCHIVED:
        raise HttpError(409, "The project is archived")
    parsed = parse_upload(fmt, data)
    ctx = _context(user, project)
    for name in parsed.columns:
        _column_for(ctx, name)
    for draft in parsed.drafts:
        _create(ctx, draft, parsed)
    progress.recompute(project.pk)
    audit(user, "project_imported", str(project.pk), format=fmt, created=len(parsed.drafts), skipped=parsed.skipped)
    if parsed.drafts:
        notices.emit_project("project.imported", project, user, created=len(parsed.drafts))
    return ImportOut(created=len(parsed.drafts), skipped=parsed.skipped, errors=parsed.errors,
                     warnings=parsed.warnings)
