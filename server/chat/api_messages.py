"""Message endpoints: list, post, edit, delete, read, seen, pins, to-task, search."""
from datetime import date
from uuid import UUID

from ninja import Router
from ninja.errors import HttpError

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, user_of
from tasks.schemas import TaskBrief
from tasks.serializers import briefs as task_briefs
from workspace.schemas import user_ref

from . import messaging, search, service, tasking
from .models import Message, PinnedMessage
from .schemas import MessageEdit, MessageIn, MessageOut, ReadIn, SeenEntry, SeenOut, ToTaskIn
from .serializers import message_outs

router = Router(tags=["chat"], auth=BearerAuth())
ERRORS = {403: Detail, 404: Detail, 409: Detail, 422: Detail, 429: Detail}
DEFAULT_LIMIT, MAX_LIMIT = 50, 100


def _one(msg: Message) -> MessageOut:
    msg = Message.objects.select_related("author", "author__org_title", "file").get(pk=msg.pk)
    return message_outs([msg])[0]


@router.get("/chat/conversations/{uuid:conversation_id}/messages", response={200: list[MessageOut], **ERRORS})
def list_messages(request, conversation_id: UUID, before_seq: int | None = None, after_seq: int | None = None,
                  limit: int = DEFAULT_LIMIT, around_date: str | None = None):
    """Ascending by seq. Default: the latest `limit`. `around_date=YYYY-MM-DD` (Asia/Tehran day) starts at the first
    message on or after that day (an empty list when there is none)."""
    user = user_of(request)
    conv = service.load(user, conversation_id)
    around = None
    if around_date:
        try:
            around = messaging.around_date_start(conv, date.fromisoformat(around_date))
        except ValueError as exc:
            raise HttpError(422, "around_date must be YYYY-MM-DD") from exc
        if around is None:
            return []
    rows = messaging.window(conv, before=before_seq, after=after_seq, around=around,
                            limit=max(min(limit, MAX_LIMIT), 1))
    return message_outs(rows)


@router.post("/chat/conversations/{uuid:conversation_id}/messages", response={201: MessageOut, **ERRORS})
def post_message(request, conversation_id: UUID, data: MessageIn):
    user = user_of(request)
    conv = service.load(user, conversation_id)
    return 201, _one(messaging.post_message(user, conv, data))


@router.patch("/chat/messages/{int:message_id}", response={200: MessageOut, **ERRORS})
def edit_message(request, message_id: int, data: MessageEdit):
    return _one(messaging.edit_message(user_of(request), message_id, data.text))


@router.delete("/chat/messages/{int:message_id}", response={200: MessageOut, **ERRORS})
def delete_message(request, message_id: int):
    messaging.delete_message(user_of(request), message_id)
    return _one(Message.objects.get(pk=message_id))


@router.post("/chat/conversations/{uuid:conversation_id}/read", response={200: dict, **ERRORS})
def read(request, conversation_id: UUID, data: ReadIn):
    user = user_of(request)
    conv = service.load(user, conversation_id)
    return {"last_read_seq": messaging.mark_read(user, conv, data.seq)}


@router.get("/chat/messages/{int:message_id}/seen", response={200: SeenOut, **ERRORS})
def seen(request, message_id: int):
    _, tracked, reads = messaging.seen_by(user_of(request), message_id)
    return SeenOut(tracked=tracked, seen=[SeenEntry(user=user_ref(r.user), at=r.at) for r in reads])


@router.post("/chat/messages/{int:message_id}/pin", response={200: MessageOut, **ERRORS})
def pin_message(request, message_id: int):
    msg, _ = messaging.set_pin(user_of(request), message_id, True)
    return _one(msg)


@router.delete("/chat/messages/{int:message_id}/pin", response={200: MessageOut, **ERRORS})
def unpin_message(request, message_id: int):
    msg, _ = messaging.set_pin(user_of(request), message_id, False)
    return _one(msg)


@router.get("/chat/conversations/{uuid:conversation_id}/pins", response={200: list[MessageOut], **ERRORS})
def pins(request, conversation_id: UUID):
    user = user_of(request)
    conv = service.load(user, conversation_id)
    ids = list(PinnedMessage.objects.filter(conversation=conv, active=True).order_by("-at")
               .values_list("message_id", flat=True))
    rows = Message.objects.filter(pk__in=ids).select_related("author", "author__org_title", "file")
    order = {i: n for n, i in enumerate(ids)}
    return message_outs(sorted(rows, key=lambda m: order[m.id]))


@router.post("/chat/messages/{int:message_id}/to-task", response={201: TaskBrief, **ERRORS})
def to_task(request, message_id: int, data: ToTaskIn | None = None):
    user = user_of(request)
    task = tasking.message_to_task(user, message_id, data or ToTaskIn())
    return 201, task_briefs(user, [task])[0]


@router.get("/chat/search", response=list[MessageOut])
def search_messages(request, q: str, conversation: UUID | None = None, limit: int = 30):
    """Scans only the 2000 most recent messages of my conversations (bodies are encrypted)."""
    service.gate()
    return message_outs(search.search(user_of(request), q, conversation, limit))
