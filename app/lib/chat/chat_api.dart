import 'dart:typed_data';

import 'package:letter_signing/chat/models.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// Typed access to the chat endpoints. Files go up through the subject endpoint of the
/// conversation first ([uploadFile]); errors 403/404/409 are typed exceptions on [workspace].
class ChatApi {
  ChatApi(this.workspace);

  final WorkspaceApi workspace;

  Future<Conversation> _conv(
    String method,
    String path, {
    Object? body,
  }) async => Conversation.fromJson(
    asMap(await workspace.call(method, path, body: body)),
  );

  Future<ChatMessage> _msg(String method, String path, {Object? body}) async =>
      ChatMessage.fromJson(
        asMap(await workspace.call(method, path, body: body)),
      );

  // Conversations

  Future<List<Conversation>> conversations(
    ConvFilter filter, {
    int limit = 100,
    int offset = 0,
  }) async {
    final q = WorkspaceApi.query(filter.toQuery(limit: limit, offset: offset));
    final data = await workspace.call('GET', '/chat/conversations$q');
    return [for (final j in asMapList(data)) Conversation.fromJson(j)];
  }

  Future<Conversation> conversation(String id) =>
      _conv('GET', '/chat/conversations/$id');

  /// Needs `chat.create_group` (403 otherwise).
  Future<Conversation> create({
    required String kind,
    required String name,
    String description = '',
    bool isPublic = false,
    List<int> memberIds = const [],
    String? postPolicy,
  }) => _conv(
    'POST',
    '/chat/conversations',
    body: {
      'kind': kind,
      'name': name,
      'description': description,
      'is_public': isPublic,
      'member_ids': memberIds,
      'post_policy': ?postPolicy,
    },
  );

  Future<Conversation> startDm(int userId) =>
      _conv('POST', '/chat/dm', body: {'user_id': userId});

  Future<Conversation> patch(
    String id, {
    String? name,
    String? description,
    bool? isPublic,
    String? postPolicy,
    bool? archived,
  }) => _conv(
    'PATCH',
    '/chat/conversations/$id',
    body: {
      'name': ?name,
      'description': ?description,
      'is_public': ?isPublic,
      'post_policy': ?postPolicy,
      'archived': ?archived,
    },
  );

  /// Replaces the member list (`[{user_id, role}]`); members left out are deactivated.
  Future<Conversation> setMembers(
    String id,
    List<({int userId, String role})> members,
  ) => _conv(
    'PUT',
    '/chat/conversations/$id/members',
    body: [
      for (final m in members) {'user_id': m.userId, 'role': m.role},
    ],
  );

  Future<Conversation> join(String id) =>
      _conv('POST', '/chat/conversations/$id/join');

  Future<void> leave(String id) =>
      workspace.call('POST', '/chat/conversations/$id/leave');

  Future<void> mute(String id, {required bool muted}) => workspace.call(
    'POST',
    '/chat/conversations/$id/mute',
    body: {'muted': muted},
  );

  Future<void> pinConversation(String id, {required bool pinned}) => workspace
      .call('POST', '/chat/conversations/$id/pin', body: {'pinned': pinned});

  /// `GET /projects/{id}/chat` and `GET /customers/{id}/chat`.
  Future<Conversation> projectChat(String projectId) =>
      _conv('GET', '/projects/$projectId/chat');

  Future<Conversation> customerChat(String customerId) =>
      _conv('GET', '/customers/$customerId/chat');

  // Messages

  /// Ascending. Default is the latest [limit]; [aroundDate] (`YYYY-MM-DD`, Tehran day) starts at
  /// the first message on or after it.
  Future<List<ChatMessage>> messages(
    String id, {
    int? beforeSeq,
    int? afterSeq,
    int limit = 50,
    String? aroundDate,
  }) async {
    final q = WorkspaceApi.query({
      'before_seq': beforeSeq,
      'after_seq': afterSeq,
      'limit': limit,
      'around_date': aroundDate,
    });
    final data = await workspace.call(
      'GET',
      '/chat/conversations/$id/messages$q',
    );
    return [for (final j in asMapList(data)) ChatMessage.fromJson(j)];
  }

  Future<ChatMessage> send(
    String id, {
    String text = '',
    int? replyToId,
    List<int> mentions = const [],
    String? fileId,
    String? kind,
  }) => _msg(
    'POST',
    '/chat/conversations/$id/messages',
    body: {
      'text': text,
      'reply_to_id': ?replyToId,
      'mentions': mentions,
      'file_id': ?fileId,
      'kind': ?kind,
    },
  );

  Future<ChatMessage> edit(int messageId, String text) =>
      _msg('PATCH', '/chat/messages/$messageId', body: {'text': text});

  Future<ChatMessage> delete(int messageId) =>
      _msg('DELETE', '/chat/messages/$messageId');

  Future<void> markRead(String id, int seq) => workspace.call(
    'POST',
    '/chat/conversations/$id/read',
    body: {'seq': seq},
  );

  Future<ChatSeenResult> seen(int messageId) async {
    final j = asMap(
      await workspace.call('GET', '/chat/messages/$messageId/seen'),
    );
    return ChatSeenResult(
      tracked: j['tracked'] == true,
      seen: [
        for (final e in asMapList(j['seen']))
          ChatSeen(
            user: UserRef.maybe(e['user']) ?? const UserRef(id: 0),
            at: parseDate(e['at']),
          ),
      ],
    );
  }

  Future<void> pinMessage(int messageId, {required bool pinned}) => workspace
      .call(pinned ? 'POST' : 'DELETE', '/chat/messages/$messageId/pin');

  Future<List<ChatMessage>> pins(String id) async => [
    for (final j in asMapList(
      await workspace.call('GET', '/chat/conversations/$id/pins'),
    ))
      ChatMessage.fromJson(j),
  ];

  // Files and bookmarks

  Future<FileInfo> uploadFile(
    Conversation c, {
    required String name,
    required Uint8List bytes,
    required String contentType,
  }) => workspace.uploadFile(
    c.subjectId,
    name: name,
    bytes: bytes,
    contentType: contentType,
  );

  Future<Uint8List> download(String fileId) => workspace.downloadFile(fileId);

  /// Idempotent `PUT /bookmarks` of a chat message.
  Future<void> bookmark(int messageId) => workspace.call(
    'PUT',
    '/bookmarks',
    body: {'module': chatBookmarkModule, 'id': '$messageId'},
  );
}
