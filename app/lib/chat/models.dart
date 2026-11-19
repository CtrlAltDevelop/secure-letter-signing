import 'package:flutter/foundation.dart';

import 'package:letter_signing/workspace/models.dart';

/// Conversation kinds as the server names them.
class ConvKind {
  static const group = 'group';
  static const channel = 'channel';
  static const dm = 'dm';
}

/// One member row of a conversation (detail only).
@immutable
class ChatMember {
  const ChatMember({
    required this.user,
    this.role = 'member',
    this.muted = false,
  });

  final UserRef user;
  final String role;
  final bool muted;

  bool get isAdmin => role == 'admin';

  factory ChatMember.fromJson(Map<String, dynamic> j) => ChatMember(
    user: UserRef.maybe(j['user']) ?? const UserRef(id: 0),
    role: asString(j['role'], 'member'),
    muted: j['muted'] == true,
  );
}

/// A conversation as `ConversationOut`.
@immutable
class Conversation {
  const Conversation({
    required this.id,
    this.subjectId = '',
    this.kind = ConvKind.group,
    this.name = '',
    this.description = '',
    this.isPublic = false,
    this.postPolicy = 'all',
    this.projectId,
    this.customerId,
    this.archived = false,
    this.memberCount = 0,
    this.isMember = true,
    this.myRole,
    this.muted = false,
    this.pinned = false,
    this.unread = 0,
    this.mentionUnread = 0,
    this.lastPreview = '',
    this.lastMessageAt,
    this.lastSeq = 0,
    this.lastReadSeq = 0,
    this.otherUser,
    this.members,
    this.canPost = true,
    this.canAdmin = false,
    this.canJoin = false,
  });

  final String id;
  final String subjectId;
  final String kind;
  final String name;
  final String description;
  final bool isPublic;
  final String postPolicy;
  final String? projectId;
  final String? customerId;
  final bool archived;
  final int memberCount;
  final bool isMember;
  final String? myRole;
  final bool muted;
  final bool pinned;
  final int unread;
  final int mentionUnread;
  final String lastPreview;
  final DateTime? lastMessageAt;
  final int lastSeq;
  final int lastReadSeq;
  final UserRef? otherUser;
  final List<ChatMember>? members;
  final bool canPost;
  final bool canAdmin;
  final bool canJoin;

  bool get isDm => kind == ConvKind.dm;
  bool get isChannel => kind == ConvKind.channel;

  /// Project and customer chats mirror their source: no member edits, no leaving.
  bool get isMirrored => projectId != null || customerId != null;

  factory Conversation.fromJson(Map<String, dynamic> j) {
    final can = asMap(j['can']);
    final members = j['members'];
    return Conversation(
      id: asString(j['id']),
      subjectId: asString(j['subject_id']),
      kind: asString(j['kind'], ConvKind.group),
      name: asString(j['name']),
      description: asString(j['description']),
      isPublic: j['is_public'] == true,
      postPolicy: asString(j['post_policy'], 'all'),
      projectId: j['project_id'] as String?,
      customerId: j['customer_id'] as String?,
      archived: j['archived'] == true,
      memberCount: asInt(j['member_count']) ?? 0,
      isMember: j['is_member'] != false,
      myRole: j['my_role'] as String?,
      muted: j['muted'] == true,
      pinned: j['pinned'] == true,
      unread: asInt(j['unread']) ?? 0,
      mentionUnread: asInt(j['mention_unread']) ?? 0,
      lastPreview: asString(j['last_message_preview']),
      lastMessageAt: parseDate(j['last_message_at']),
      lastSeq: asInt(j['last_seq']) ?? 0,
      lastReadSeq: asInt(j['last_read_seq']) ?? 0,
      otherUser: UserRef.maybe(j['other_user']),
      members: members is List
          ? [for (final m in asMapList(members)) ChatMember.fromJson(m)]
          : null,
      canPost: can['post'] != false,
      canAdmin: can['admin'] == true,
      canJoin: can['join'] == true,
    );
  }

  Conversation copyWith({
    int? unread,
    int? mentionUnread,
    int? lastSeq,
    int? lastReadSeq,
    String? lastPreview,
    DateTime? lastMessageAt,
    bool? pinned,
    bool? muted,
  }) => Conversation(
    id: id,
    subjectId: subjectId,
    kind: kind,
    name: name,
    description: description,
    isPublic: isPublic,
    postPolicy: postPolicy,
    projectId: projectId,
    customerId: customerId,
    archived: archived,
    memberCount: memberCount,
    isMember: isMember,
    myRole: myRole,
    muted: muted ?? this.muted,
    pinned: pinned ?? this.pinned,
    unread: unread ?? this.unread,
    mentionUnread: mentionUnread ?? this.mentionUnread,
    lastPreview: lastPreview ?? this.lastPreview,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    lastSeq: lastSeq ?? this.lastSeq,
    lastReadSeq: lastReadSeq ?? this.lastReadSeq,
    otherUser: otherUser,
    members: members,
    canPost: canPost,
    canAdmin: canAdmin,
    canJoin: canJoin,
  );
}

/// The file attached to a message.
@immutable
class ChatFile {
  const ChatFile({
    required this.id,
    this.name = '',
    this.contentType = '',
    this.size = 0,
  });

  final String id;
  final String name;
  final String contentType;
  final int size;

  bool get isImage => contentType.startsWith('image/');
  bool get isAudio => contentType.startsWith('audio/');

  factory ChatFile.fromJson(Map<String, dynamic> j) => ChatFile(
    id: asString(j['id']),
    name: asString(j['name']),
    contentType: asString(j['content_type']),
    size: asInt(j['size']) ?? 0,
  );
}

/// The quoted message of a reply.
@immutable
class ReplyRef {
  const ReplyRef({
    required this.id,
    this.seq = 0,
    this.authorId = 0,
    this.preview = '',
  });

  final int id;
  final int seq;
  final int authorId;
  final String preview;

  factory ReplyRef.fromJson(Map<String, dynamic> j) => ReplyRef(
    id: asInt(j['id']) ?? 0,
    seq: asInt(j['seq']) ?? 0,
    authorId: asInt(j['author_id']) ?? 0,
    preview: asString(j['preview']),
  );
}

/// One message (`MessageOut`). A deleted message is a tombstone: no text, file or mentions.
@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.seq,
    required this.author,
    this.kind = 'text',
    this.text = '',
    this.replyTo,
    this.mentions = const [],
    this.file,
    this.data,
    this.createdAt,
    this.edited = false,
    this.deleted = false,
    this.pinned = false,
  });

  final int id;
  final String conversationId;
  final int seq;
  final UserRef author;
  final String kind;
  final String text;
  final ReplyRef? replyTo;
  final List<int> mentions;
  final ChatFile? file;
  final Map<String, dynamic>? data;
  final DateTime? createdAt;
  final bool edited;
  final bool deleted;
  final bool pinned;

  bool get isSystem => kind == 'system';
  bool get isTaskCreated => isSystem && data?['event'] == 'task_created';

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: asInt(j['id']) ?? 0,
    conversationId: asString(j['conversation_id']),
    seq: asInt(j['seq']) ?? 0,
    author: UserRef.maybe(j['author']) ?? const UserRef(id: 0),
    kind: asString(j['kind'], 'text'),
    text: asString(j['text']),
    replyTo: j['reply_to'] is Map
        ? ReplyRef.fromJson(asMap(j['reply_to']))
        : null,
    mentions: asIntList(j['mentions']),
    file: j['file'] is Map ? ChatFile.fromJson(asMap(j['file'])) : null,
    data: j['data'] is Map ? asMap(j['data']) : null,
    createdAt: parseDate(j['created_at']),
    edited: j['edited'] == true,
    deleted: j['deleted'] == true,
    pinned: j['pinned'] == true,
  );

  ChatMessage copyWith({bool? pinned, bool? deleted, String? text}) =>
      ChatMessage(
        id: id,
        conversationId: conversationId,
        seq: seq,
        author: author,
        kind: kind,
        text: deleted == true ? '' : (text ?? this.text),
        replyTo: replyTo,
        mentions: mentions,
        file: deleted == true ? null : file,
        data: data,
        createdAt: createdAt,
        edited: edited,
        deleted: deleted ?? this.deleted,
        pinned: pinned ?? this.pinned,
      );
}

/// One reader of a message (`GET /chat/messages/{id}/seen`).
@immutable
class ChatSeen {
  const ChatSeen({required this.user, this.at});
  final UserRef user;
  final DateTime? at;
}

/// `tracked` is false for conversations above the receipt cap.
@immutable
class ChatSeenResult {
  const ChatSeenResult({required this.tracked, required this.seen});
  final bool tracked;
  final List<ChatSeen> seen;
}

/// A bookmark target is a message id of the `chat` module.
const chatBookmarkModule = 'chat';

/// List filters of the conversation list.
@immutable
class ConvFilter {
  const ConvFilter({this.q = '', this.publicOnly = false, this.kind});

  final String q;
  final bool publicOnly;
  final String? kind;

  ConvFilter copyWith({
    String? q,
    bool? publicOnly,
    String? kind,
    bool clearKind = false,
  }) => ConvFilter(
    q: q ?? this.q,
    publicOnly: publicOnly ?? this.publicOnly,
    kind: clearKind ? null : (kind ?? this.kind),
  );

  Map<String, Object?> toQuery({int limit = 100, int offset = 0}) => {
    'q': q.isEmpty ? null : q,
    'kind': kind,
    if (publicOnly) 'public': 'true' else 'mine': 'true',
    'limit': limit,
    'offset': offset,
  };
}
