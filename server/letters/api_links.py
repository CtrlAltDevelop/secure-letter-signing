"""Letter extras: linked tasks, paraph, customer files."""
from uuid import UUID

from ninja import Router
from ninja.errors import HttpError

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, user_of

from . import access, paraphs, rules, secretariat, signing, task_links
from .schemas import CustomerRefsIn, CustomerRefsOut, LetterTaskIn, ParaphOut, ParaphPinIn, TaskBrief

router = Router(tags=["letters"], auth=BearerAuth())


# --- tasks ---------------------------------------------------------------------------------------------------


@router.get("/{uuid:letter_id}/tasks", response=list[TaskBrief])
def list_tasks(request, letter_id: UUID):
    user = user_of(request)
    return task_links.linked(user, access.get_visible(user, letter_id))


@router.post("/{uuid:letter_id}/tasks", response={201: TaskBrief})
def add_task(request, letter_id: UUID, data: LetterTaskIn):
    user = user_of(request)
    return 201, task_links.link(user, access.get_visible(user, letter_id), data.task_id)


@router.delete("/{uuid:letter_id}/tasks/{uuid:task_id}", response={204: None})
def remove_task(request, letter_id: UUID, task_id: UUID):
    user = user_of(request)
    task_links.unlink(user, access.get_visible(user, letter_id), task_id)
    return 204, None


# --- paraph --------------------------------------------------------------------------------------------------


@router.post("/{uuid:letter_id}/paraph", response={201: ParaphOut})
def paraph_pin(request, letter_id: UUID, data: ParaphPinIn):
    """Initial the letter with the signing PIN. Not atomic as a whole: a wrong PIN keeps its failure count."""
    user = user_of(request)
    paraphs.require_can_paraph(access.get_visible(user, letter_id), user)  # outsiders cannot burn PIN attempts
    signing.check_pin(user, data.pin, request.auth)
    return 201, paraphs.paraph_out(paraphs.record(letter_id, user, request.auth, "pin"))


@router.post("/{uuid:letter_id}/paraph-biometric", response={201: ParaphOut})
def paraph_biometric(request, letter_id: UUID):
    user = user_of(request)
    if not request.auth.biometric:
        raise HttpError(403, "This session has no biometrics")
    access.get_visible(user, letter_id)
    return 201, paraphs.paraph_out(paraphs.record(letter_id, user, request.auth, "biometric"))


# --- customer files ------------------------------------------------------------------------------------------


@router.put("/{uuid:letter_id}/customers", response={200: CustomerRefsOut, 403: Detail})
def set_customers(request, letter_id: UUID, data: CustomerRefsIn):
    """The creator or a secretariat member who can see the letter replaces its customer links."""
    user = user_of(request)
    letter = access.get_visible(user, letter_id)
    if letter.creator_id != user.id and not rules.has_secretariat(user):
        raise HttpError(403, "Only the creator or the secretariat can link customers")
    return CustomerRefsOut(customer_refs=secretariat.set_customers(user, letter.subject, data.customer_refs))
