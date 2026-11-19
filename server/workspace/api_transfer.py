"""`POST /users/{id}/transfer`: the manager hands a colleague's open work to another active user."""
from django.shortcuts import get_object_or_404
from ninja import Router, Schema
from ninja.errors import HttpError

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, require_manager
from accounts.models import User

from . import transfer

router = Router(tags=["workspace"], auth=BearerAuth())


class TransferIn(Schema):
    to_user_id: int


class TransferOut(Schema):
    moved: dict[str, int]


@router.post("/users/{int:user_id}/transfer", response={200: TransferOut, 403: Detail, 404: Detail, 422: Detail})
def transfer_work(request, user_id: int, data: TransferIn):
    manager = require_manager(request)
    source = get_object_or_404(User, pk=user_id)
    target = get_object_or_404(User, pk=data.to_user_id)
    if source.pk == target.pk:
        raise HttpError(422, "The target must be a different user")
    if not target.is_active:
        raise HttpError(422, "The target user is inactive")
    return TransferOut(moved=transfer.transfer_work(source, target, manager))
