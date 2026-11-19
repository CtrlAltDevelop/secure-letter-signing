"""Message -> task: a normal task is created through the tasks service and linked back by a system message."""
from django.db import transaction
from ninja.errors import HttpError

from accounts.models import User, audit
from tasks.models import Task
from tasks.schemas import DescriptionIn, TaskIn
from tasks.service import create_task

from . import bodies, events, messaging
from .events import preview_of
from .models import Message
from .schemas import ToTaskIn

TITLE_CHARS = 80


@transaction.atomic
def message_to_task(user: User, message_id: int, data: ToTaskIn) -> Task:
    msg, conv = messaging.message_of(user, message_id)
    if not user.has_grant("task.create"):
        raise HttpError(403, "Permission denied")
    if msg.deleted or msg.kind == Message.SYSTEM:
        raise HttpError(409, "This message cannot become a task")
    text = bodies.open_text(msg.body)
    title = (data.title or preview_of(text)[:TITLE_CHARS]).strip()
    if not title:
        raise HttpError(422, "A title is required")
    task = create_task(user, TaskIn(
        title=title, description=DescriptionIn(text=text), owner_ids=data.owner_ids, due_at=data.due_at,
        project_id=data.project_id))
    link = messaging.store(conv, user, kind=Message.SYSTEM, reply_to=msg,
                           body=bodies.seal_body(title, event="task_created", task_id=str(task.id)))
    audit(user, "chat_message_to_task", str(msg.id), task=str(task.id), conversation=str(conv.id))
    events.message_created(conv, link, title)
    return task
