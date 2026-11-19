import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:letter_signing/chat/chat_api.dart';
import 'package:letter_signing/chat/chat_env.dart';
import 'package:letter_signing/tasks/tasks_api.dart';
import 'package:letter_signing/tasks/tasks_env.dart';
import 'package:letter_signing/workspace/file_pick.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

import '../letters/fakes.dart';

Map<String, dynamic> userJson(int id, String name) => {
  'id': id,
  'full_name': name,
  'email': 'u$id@x.test',
};

Map<String, dynamic> convJson(
  String id, {
  String kind = 'group',
  String name = 'Team',
  int unread = 0,
  bool pinned = false,
  bool muted = false,
  bool isMember = true,
  bool isPublic = false,
  int lastSeq = 0,
  int lastReadSeq = 0,
  String preview = '',
  String? lastAt = '2026-03-01T10:00:00Z',
  bool canAdmin = false,
  bool canPost = true,
  Map<String, dynamic>? other,
  List<Map<String, dynamic>>? members,
}) => {
  'id': id,
  'subject_id': 'sub-$id',
  'kind': kind,
  'name': name,
  'description': '',
  'is_public': isPublic,
  'post_policy': 'all',
  'project_id': null,
  'customer_id': null,
  'archived': false,
  'creator_id': 1,
  'member_count': 3,
  'is_member': isMember,
  'my_role': isMember ? 'member' : null,
  'muted': muted,
  'pinned': pinned,
  'unread': unread,
  'mention_unread': 0,
  'last_message_preview': preview,
  'last_message_at': lastAt,
  'last_seq': lastSeq,
  'last_read_seq': lastReadSeq,
  'other_user': other,
  'members': members,
  'can': {'post': canPost, 'admin': canAdmin, 'join': !isMember && isPublic},
  'created_at': '2026-01-01T00:00:00Z',
};

Map<String, dynamic> msgJson(
  int id,
  int seq, {
  String conv = 'c1',
  int author = 3,
  String authorName = 'Sara',
  String text = 'hello',
  String kind = 'text',
  bool deleted = false,
  bool pinned = false,
  List<int> mentions = const [],
  Map<String, dynamic>? file,
  Map<String, dynamic>? replyTo,
  String at = '2026-03-01T10:00:00Z',
}) => {
  'id': id,
  'conversation_id': conv,
  'seq': seq,
  'author': userJson(author, authorName),
  'kind': kind,
  'text': deleted ? '' : text,
  'reply_to': replyTo,
  'mentions': mentions,
  'file': file,
  'data': null,
  'created_at': at,
  'edited_at': null,
  'edited': false,
  'deleted': deleted,
  'pinned': pinned,
};

/// A scripted in-memory chat server; every request is recorded with its JSON body.
class FakeChatServer {
  final List<Map<String, dynamic>> conversations = [];
  final Map<String, List<Map<String, dynamic>>> messages = {};
  final List<Map<String, dynamic>> users = [
    userJson(2, 'Me'),
    userJson(3, 'Sara'),
    userJson(4, 'Ali'),
  ];
  final List<http.Request> calls = [];
  final List<Object?> bodies = [];
  int _next = 1000;

  Iterable<http.Request> where(String method, String part) =>
      calls.where((r) => r.method == method && r.url.path.contains(part));

  Object? lastBody(String method, String part) {
    for (var i = calls.length - 1; i >= 0; i--) {
      if (calls[i].method == method && calls[i].url.path.contains(part)) {
        return bodies[i];
      }
    }
    return null;
  }

  http.Response handle(http.Request req, Object? body) {
    calls.add(req);
    bodies.add(body);
    final path = req.url.path.replaceFirst('/api', '');
    final m = req.method;
    final q = req.url.queryParameters;
    if (path == '/letters/directory') return json(users);
    if (path == '/chat/conversations' && m == 'GET') return _list(q);
    if (path == '/chat/conversations' && m == 'POST') {
      return _create(body as Map);
    }
    if (path.endsWith('/chat') &&
        (path.startsWith('/projects/') || path.startsWith('/customers/'))) {
      return json(conversations.first);
    }
    if (path == '/chat/dm') {
      final c = convJson('dm1', kind: 'dm', name: 'Sara', other: users[1]);
      return json(c);
    }
    if (path.startsWith('/chat/conversations/')) {
      return _conversation(path.split('/'), m, q, body);
    }
    if (path.startsWith('/chat/messages/')) return _message(path.split('/'), m);
    if (path == '/bookmarks') return json({'id': 1}, 200);
    if (path.startsWith('/subjects/') && path.endsWith('/files')) {
      return json({
        'id': 'f1',
        'name': (body is Map ? body['name'] : null) ?? 'p.png',
        'content_type': 'image/png',
        'size': 3,
      }, 201);
    }
    if (path.startsWith('/files/')) {
      return http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200);
    }
    return json(<Object>[]);
  }

  http.Response _list(Map<String, String> q) {
    final pub = q['public'] == 'true';
    final needle = (q['q'] ?? '').toLowerCase();
    final rows = [
      for (final c in conversations)
        if ((pub ? c['is_public'] == true : c['is_member'] == true) &&
            (q['kind'] == null || c['kind'] == q['kind']) &&
            (needle.isEmpty || '${c['name']}'.toLowerCase().contains(needle)))
          c,
    ];
    return json(rows);
  }

  http.Response _create(Map body) {
    final c = convJson(
      'new${_next++}',
      kind: body['kind'] as String,
      name: body['name'] as String,
    );
    conversations.add(c);
    return json(c, 201);
  }

  http.Response _conversation(
    List<String> seg,
    String m,
    Map<String, String> q,
    Object? body,
  ) {
    final id = seg[3];
    final tail = seg.length > 4 ? seg[4] : '';
    final conv = conversations.firstWhere((c) => c['id'] == id);
    final rows = messages.putIfAbsent(id, () => []);
    if (tail == '') return json(conv);
    if (tail == 'pins') {
      return json([
        for (final r in rows)
          if (r['pinned'] == true) r,
      ]);
    }
    if (tail == 'read') return json({'last_read_seq': (body as Map)['seq']});
    if (tail == 'join') return json({...conv, 'is_member': true});
    if (tail == 'messages' && m == 'POST') return _post(id, rows, body as Map);
    if (tail == 'messages') return json(_page(rows, q));
    return json(<String, dynamic>{});
  }

  List<Map<String, dynamic>> _page(
    List<Map<String, dynamic>> rows,
    Map<String, String> q,
  ) {
    final limit = int.tryParse(q['limit'] ?? '') ?? 50;
    var sel = [...rows]..sort((a, b) => (a['seq'] as int) - (b['seq'] as int));
    final before = int.tryParse(q['before_seq'] ?? '');
    final after = int.tryParse(q['after_seq'] ?? '');
    if (q['around_date'] != null) {
      sel = [
        for (final r in sel)
          if ('${r['created_at']}'
                  .substring(0, 10)
                  .compareTo(q['around_date']!) >=
              0)
            r,
      ];
      return sel.take(limit).toList();
    }
    if (before != null) {
      sel = [
        for (final r in sel)
          if ((r['seq'] as int) < before) r,
      ];
      return sel.length > limit ? sel.sublist(sel.length - limit) : sel;
    }
    if (after != null) {
      sel = [
        for (final r in sel)
          if ((r['seq'] as int) > after) r,
      ];
      return sel.take(limit).toList();
    }
    return sel.length > limit ? sel.sublist(sel.length - limit) : sel;
  }

  http.Response _post(String conv, List<Map<String, dynamic>> rows, Map body) {
    final seq = rows.length + 1;
    final msg = msgJson(
      _next++,
      seq,
      conv: conv,
      author: 2,
      authorName: 'Me',
      text: body['text'] as String,
      mentions: (body['mentions'] as List).cast<int>(),
      kind:
          (body['kind'] as String?) ??
          (body['file_id'] != null ? 'file' : 'text'),
      file: body['file_id'] == null
          ? null
          : {
              'id': body['file_id'],
              'name': 'p.png',
              'content_type': 'image/png',
              'size': 3,
            },
    );
    rows.add(msg);
    return json(msg, 201);
  }

  http.Response _message(List<String> seg, String m) {
    final id = int.parse(seg[3]);
    if (seg.length > 4 && seg[4] == 'seen') {
      return json({
        'tracked': true,
        'seen': [
          {'user': userJson(3, 'Sara'), 'at': '2026-03-01T11:00:00Z'},
        ],
      });
    }
    for (final rows in messages.values) {
      for (final (i, r) in rows.indexed) {
        if (r['id'] != id) continue;
        if (m == 'DELETE') {
          rows[i] = msgJson(
            id,
            r['seq'] as int,
            conv: r['conversation_id'] as String,
            deleted: true,
          );
        }
        if (seg.length > 4 && seg[4] == 'pin') r['pinned'] = m == 'POST';
        return json(rows[i]);
      }
    }
    return json({'detail': 'nf'}, 404);
  }
}

({ChatEnv env, FakeLive live}) chatEnv(
  FakeChatServer server, {
  FilePickFn? pick,
  bool canCreate = true,
  ClipboardImageFn? clipboardImage,
  VoiceRecordFn? record,
}) {
  final f = fakeApi(server.handle);
  final ws = WorkspaceApi(f.client, httpClient: f.api.httpClient);
  final live = FakeLive(f.client);
  final tasks = TasksEnv(
    api: TasksApi(f.client, httpClient: f.api.httpClient),
    live: live,
    userId: 2,
  );
  final env = ChatEnv(
    api: ChatApi(ws),
    live: live,
    userId: 2,
    userName: 'Me',
    tasks: tasks,
    canCreateGroup: canCreate,
    pickFile: pick,
    readClipboardImage: clipboardImage,
    recordVoice: record,
  );
  return (env: env, live: live);
}

/// A live workspace frame of the chat module.
Map<String, dynamic> chatFrame(
  String kind,
  String conv,
  Map<String, dynamic> data,
) => {
  'type': 'ws',
  'stream': 'w',
  'event_id': 1,
  'module': 'chat',
  'kind': kind,
  'data': {'conversation_id': conv, ...data},
};

Future<PickedFile?> pickImage() async => PickedFile(
  name: 'p.png',
  bytes: Uint8List.fromList([1, 2, 3]),
  contentType: 'image/png',
);
