"""Work transfer: the manager moves a (possibly deactivated) colleague's open work to someone else.

Every module that registered a `ModuleSpec.transfer` callback takes part, all in one transaction. Projects run before
tasks so the target is a project member before their tasks move. Audit rows carry ids and counts only.
"""
from django.db import transaction

from accounts.models import User, audit
from accounts.notify import notify

from . import registry

FIRST = ("projects", "tasks")


def _order(spec: registry.ModuleSpec) -> tuple[int, str]:
    return (FIRST.index(spec.code) if spec.code in FIRST else len(FIRST), spec.code)


def _merge(moved: dict[str, int], spec: registry.ModuleSpec, result: int | dict[str, int]) -> None:
    for key, count in ({spec.code: result} if isinstance(result, int) else result).items():
        moved[key] = moved.get(key, 0) + count


@transaction.atomic
def transfer_work(from_user: User, to_user: User, actor: User) -> dict[str, int]:
    enabled = registry.enabled_modules()
    moved: dict[str, int] = {}
    for spec in sorted((s for s in registry.all_specs() if s.transfer and s.code in enabled), key=_order):
        _merge(moved, spec, spec.transfer(from_user, to_user, actor))
    audit(actor, "work_transferred", str(from_user.id), to=to_user.id, moved=moved)
    notify([to_user], "work.transferred", from_user.full_name or from_user.email, moved=moved,
           from_user_id=from_user.id)
    return moved
