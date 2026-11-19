"""Chat API (mounted at ""): conversations under /chat/conversations, messages in api_messages, sources in api_sources."""
from uuid import UUID

from django.db.models import F, Q
from ninja import Router

from accounts.api_auth import Detail
from accounts.auth import BearerAuth, user_of
from accounts.models import User

from . import service
from .api_messages import router as messages_router
from .api_sources import router as sources_router
from .models import Conversation, ConversationMember
from .schemas import (ConversationIn, ConversationOut, ConversationPatch, DmIn, MemberIn, MuteIn, PinIn, UnreadEntry,
                      UnreadOut)
from .serializers import conversation_outs
from .unread import counts_for

router = Router(tags=["chat"], auth=BearerAuth())
ERRORS = {403: Detail, 404: Detail, 409: Detail, 422: Detail}
MAX_LIMIT = 200


def _out(user: User, conv: Conversation) -> ConversationOut:
    return conversation_outs(user, [conv], detail=True)[0]


def _listing(user: User, kind: str, q: str, mine: bool):
    if mine:
        qs = (Conversation.objects.filter(members__user=user, members__active=True)
              .annotate(my_pinned=F("members__pinned"))
              .order_by("-my_pinned", F("last_message_at").desc(nulls_last=True), "-created_at"))
    else:
        qs = Conversation.objects.filter(is_public=True, archived=False, project__isnull=True,
                                         customer_ref__isnull=True).exclude(kind=Conversation.DM)
        qs = qs.order_by("name", "created_at")
    if kind:
        qs = qs.filter(kind=kind)
    if q.strip():
        dms = (ConversationMember.objects.filter(conversation__kind=Conversation.DM)
               .filter(Q(user__full_name__icontains=q) | Q(user__email__icontains=q)).exclude(user=user)
               .values("conversation_id"))
        qs = qs.filter(Q(name__icontains=q) | Q(id__in=dms))
    return qs.select_related("subject")


@router.get("/chat/conversations", response=list[ConversationOut])
def list_conversations(request, kind: str = "", q: str = "", mine: bool = False, public: bool = False,
                       limit: int = 100, offset: int = 0):
    """`mine=true` (the default when neither flag is set): my conversations; `public=true`: discoverable public ones."""
    service.gate()
    user = user_of(request)
    start = max(offset, 0)
    page = _listing(user, kind, q, mine or not public)[start : start + max(min(limit, MAX_LIMIT), 0)]
    return conversation_outs(user, list(page))


@router.post("/chat/conversations", response={201: ConversationOut, **ERRORS})
def create_conversation(request, data: ConversationIn):
    user = user_of(request)
    return 201, _out(user, service.create_conversation(user, data))


@router.post("/chat/dm", response={200: ConversationOut, **ERRORS})
def open_dm(request, data: DmIn):
    service.gate()
    user = user_of(request)
    return _out(user, service.open_dm(user, data.user_id))


@router.get("/chat/unread", response=UnreadOut)
def unread_totals(request):
    service.gate()
    counts = counts_for(user_of(request))
    entries = [UnreadEntry(conversation_id=cid, unread=c.unread, mention_unread=c.mentions, muted=c.muted)
               for cid, c in counts.items() if c.unread or c.mentions]
    return UnreadOut(total=sum(e.unread for e in entries if not e.muted),
                     mentions=sum(e.mention_unread for e in entries), conversations=entries)


@router.get("/chat/conversations/{uuid:conversation_id}", response={200: ConversationOut, 404: Detail})
def get_conversation(request, conversation_id: UUID):
    """Members see everything; anyone may read the metadata of a public conversation (to decide to join)."""
    user = user_of(request)
    return _out(user, service.load(user, conversation_id, member_only=False))


@router.patch("/chat/conversations/{uuid:conversation_id}", response={200: ConversationOut, **ERRORS})
def patch_conversation(request, conversation_id: UUID, data: ConversationPatch):
    user = user_of(request)
    conv = service.load(user, conversation_id)
    return _out(user, service.update_conversation(user, conv, data))


@router.put("/chat/conversations/{uuid:conversation_id}/members", response={200: ConversationOut, **ERRORS})
def put_members(request, conversation_id: UUID, data: list[MemberIn]):
    user = user_of(request)
    conv = service.load(user, conversation_id)
    service.set_members(user, conv, data)
    return _out(user, conv)


@router.post("/chat/conversations/{uuid:conversation_id}/join", response={200: ConversationOut, **ERRORS})
def join(request, conversation_id: UUID):
    user = user_of(request)
    conv = service.load(user, conversation_id, member_only=False)
    return _out(user, service.join(user, conv))


@router.post("/chat/conversations/{uuid:conversation_id}/leave", response={204: None, **ERRORS})
def leave(request, conversation_id: UUID):
    user = user_of(request)
    service.leave(user, service.load(user, conversation_id))
    return 204, None


@router.post("/chat/conversations/{uuid:conversation_id}/mute", response={200: ConversationOut, **ERRORS})
def mute(request, conversation_id: UUID, data: MuteIn):
    user = user_of(request)
    conv = service.load(user, conversation_id)
    service.set_flag(user, conv, muted=data.muted)
    return _out(user, conv)


@router.post("/chat/conversations/{uuid:conversation_id}/pin", response={200: ConversationOut, **ERRORS})
def pin(request, conversation_id: UUID, data: PinIn):
    user = user_of(request)
    conv = service.load(user, conversation_id)
    service.set_flag(user, conv, pinned=data.pinned)
    return _out(user, conv)


router.add_router("", messages_router)
router.add_router("", sources_router)
