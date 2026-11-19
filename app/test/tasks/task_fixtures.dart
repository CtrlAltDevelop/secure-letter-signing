import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/tasks/tasks_api.dart';
import 'package:letter_signing/tasks/tasks_env.dart';
import 'package:letter_signing/workspace/file_pick.dart';

import '../letters/fakes.dart';

const me = {'id': 2, 'full_name': 'Me', 'email': 'me@x.test'};
const bob = {'id': 3, 'full_name': 'Bob', 'email': 'bob@x.test'};
const carol = {'id': 4, 'full_name': 'Carol', 'email': 'carol@x.test'};

Map<String, dynamic> canJson({
  bool edit = false,
  bool progress = false,
  bool approve = false,
  bool comment = true,
  bool? complete,
  bool? reopen,
}) => {
  'edit': edit,
  'progress': progress,
  'approve': approve,
  'comment': comment,
  'complete': ?complete,
  'reopen': ?reopen,
};

Map<String, dynamic> briefTask(
  String id, {
  String title = 'Task',
  String status = 'open',
  String priority = 'normal',
  int progress = 0,
  String? dueAt,
  bool allDay = false,
  bool unseen = false,
  List<int> labelIds = const [],
  Map<String, int> checklist = const {'done': 0, 'total': 0},
}) => {
  'id': id,
  'subject_id': 's-$id',
  'title': title,
  'status': status,
  'priority': priority,
  'progress': progress,
  'due_at': dueAt,
  'all_day': allDay,
  'project_id': null,
  'owner_ids': [2],
  'my_roles': ['owner'],
  'label_ids': labelIds,
  'checklist': checklist,
  'unseen': unseen,
  'updated_at': '2026-01-01T00:00:00Z',
};

Map<String, dynamic> fullTask(
  String id, {
  String title = 'Task',
  String status = 'open',
  String description = '',
  Map<String, dynamic>? can,
  int version = 1,
  int progress = 0,
  String progressMode = 'manual',
  List<Map<String, dynamic>> items = const [],
  List<Map<String, dynamic>> approvers = const [],
  String? dueAt,
}) => {
  ...briefTask(
    id,
    title: title,
    status: status,
    progress: progress,
    dueAt: dueAt,
  ),
  'description': {'text': description},
  'creator': me,
  'owners': [me],
  'approvers': approvers,
  'followers': <Map<String, dynamic>>[],
  'checklist_items': items,
  'start_at': null,
  'progress_mode': progressMode,
  'version': version,
  'completed_at': null,
  'created_at': '2026-01-01T00:00:00Z',
  'comment_count': 0,
  'file_count': 0,
  'can': can ?? canJson(edit: true, progress: true),
};

Map<String, dynamic> checkItem(int id, String text, {bool done = false}) => {
  'id': id,
  'text': text,
  'done': done,
  'done_by': null,
  'done_at': null,
};

Map<String, dynamic> commentJson(
  int id,
  String text, {
  Map<String, dynamic> author = me,
  int? parentId,
  String kind = 'comment',
  List<Map<String, dynamic>> replies = const [],
}) => {
  'id': id,
  'author': author,
  'parent_id': parentId,
  'kind': kind,
  'body': {'text': text},
  'progress': null,
  'edited': false,
  'created_at': '2026-01-01T00:00:00Z',
  'replies': replies,
};

Map<String, dynamic> fileJson(String id, String name, {int uploader = 2}) => {
  'id': id,
  'name': name,
  'content_type': 'application/pdf',
  'size': 2048,
  'uploaded_by': uploader == 2 ? me : bob,
  'created_at': '2026-01-01T00:00:00Z',
};

/// A scripted in-memory tasks server. Mutations update [tasks]; tests tweak the maps, or set
/// [conflictNext] to make the next write fail with 409.
class FakeTasksServer {
  FakeTasksServer({List<Map<String, dynamic>>? tasks}) : tasks = tasks ?? [];

  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> comments = [];
  final List<Map<String, dynamic>> files = [];
  final List<Map<String, dynamic>> labels = [];
  List<Map<String, dynamic>> directory = [me, bob, carol];
  final List<http.BaseRequest> calls = [];
  final List<Object?> bodies = [];
  bool conflictNext = false;

  /// Status code for the next request only (then back to normal).
  int? failNext;
  int _nextId = 100;

  Iterable<http.BaseRequest> where(String method, String pathPart) =>
      calls.where((r) => r.method == method && r.url.path.contains(pathPart));

  Object? lastBody(String method, String pathPart) {
    for (var i = calls.length - 1; i >= 0; i--) {
      final r = calls[i];
      if (r.method == method && r.url.path.contains(pathPart)) {
        return bodies[i];
      }
    }
    return null;
  }

  Map<String, dynamic>? _find(String id) =>
      tasks.where((t) => t['id'] == id).firstOrNull;

  Future<http.Response> handle(http.BaseRequest req) async {
    calls.add(req);
    Object? body;
    if (req is http.Request && req.body.isNotEmpty) {
      body = jsonDecode(req.body);
    }
    bodies.add(body);
    final fail = failNext;
    if (fail != null) {
      failNext = null;
      return json({'detail': 'boom'}, fail);
    }
    return _route(req, body);
  }

  http.Response _route(http.BaseRequest req, Object? body) {
    final path = req.url.path.replaceFirst('/api', '');
    final m = req.method;
    if (path == '/labels') return json(labels);
    if (path == '/letters/directory') return json(directory);
    if (path == '/tasks' && m == 'GET') return _list(req.url);
    if (path == '/tasks' && m == 'POST') return _create(body as Map);
    final seg = path.split('/');
    if (seg[1] == 'tasks') return _taskRoute(m, seg, body);
    if (seg[1] == 'subjects') return _subjectRoute(m, seg, body);
    if (seg[1] == 'comments') return _commentRoute(m, int.parse(seg[2]), body);
    if (seg[1] == 'files') return _fileRoute(m, seg[2]);
    return json({'detail': 'Not found'}, 404);
  }

  http.Response _list(Uri url) {
    final status = url.queryParameters['status'] ?? '';
    final q = (url.queryParameters['q'] ?? '').toLowerCase();
    final limit = int.parse(url.queryParameters['limit'] ?? '50');
    final offset = int.parse(url.queryParameters['offset'] ?? '0');
    final rows = [
      for (final t in tasks)
        if ((status.isEmpty || t['status'] == status) &&
            (q.isEmpty || '${t['title']}'.toLowerCase().contains(q)))
          t,
    ];
    return json(rows.skip(offset).take(limit).toList());
  }

  http.Response _create(Map body) {
    final id = 't${_nextId++}';
    final t = fullTask(id, title: body['title'] as String);
    tasks.add(t);
    return json(t, 201);
  }

  http.Response _taskRoute(String m, List<String> seg, Object? body) {
    final t = _find(seg[2]);
    if (t == null) return json({'detail': 'Not found'}, 404);
    final action = seg.length > 3 ? seg[3] : '';
    if (action == 'seen') return http.Response('', 204);
    if (m == 'GET') return json(t);
    if (conflictNext) {
      conflictNext = false;
      return json({'detail': 'Version conflict'}, 409);
    }
    final map = body is Map ? body : const {};
    switch (action) {
      case '':
        t.addAll({
          for (final e in map.entries)
            if (e.key != 'version') e.key: e.value,
        });
      case 'checklist':
        _checklist(t, seg, m, map);
      case 'complete':
        t['status'] = 'done';
      case 'decision':
        t['status'] = map['decision'] == 'approve' ? 'done' : 'open';
      case 'reopen':
        t['status'] = 'open';
      case 'cancel':
        t['status'] = 'cancelled';
    }
    t['version'] = (t['version'] as int) + 1;
    return json(t);
  }

  void _checklist(
    Map<String, dynamic> t,
    List<String> seg,
    String m,
    Map body,
  ) {
    final items = (t['checklist_items'] as List).cast<Map<String, dynamic>>();
    if (m == 'POST') {
      items.add(checkItem(items.length + 50, body['text'] as String));
    } else if (seg.length > 4 && seg[4] == 'order') {
      final ids = (body['item_ids'] as List).cast<int>();
      items.sort(
        (a, b) =>
            ids.indexOf(a['id'] as int).compareTo(ids.indexOf(b['id'] as int)),
      );
    } else {
      final item = items.firstWhere((i) => i['id'].toString() == seg[4]);
      if (body['done'] != null) item['done'] = body['done'];
      if (body['active'] == false) items.remove(item);
    }
    final done = items.where((i) => i['done'] == true).length;
    t['checklist'] = {'done': done, 'total': items.length};
  }

  http.Response _subjectRoute(String m, List<String> seg, Object? body) {
    final kind = seg[3];
    if (kind == 'comments' && m == 'GET') return json(comments);
    if (kind == 'comments') {
      final b = body as Map;
      final id = 500 + comments.length;
      final parent = b['parent_id'] as int?;
      final c = commentJson(
        id,
        (b['body'] as Map)['text'] as String,
        parentId: parent,
        kind: b['kind'] as String,
      );
      final host = comments.where((x) => x['id'] == parent).firstOrNull;
      if (host != null) {
        (host['replies'] as List).add(c);
      } else {
        comments.add(c);
      }
      return json(c, 201);
    }
    if (kind == 'files') return json(files);
    if (kind == 'history') return json([]);
    if (kind == 'seen') return json([]);
    return json({'detail': 'Not found'}, 404);
  }

  Map<String, dynamic>? _comment(int id) {
    for (final c in comments) {
      if (c['id'] == id) return c;
      for (final r in (c['replies'] as List).cast<Map<String, dynamic>>()) {
        if (r['id'] == id) return r;
      }
    }
    return null;
  }

  http.Response _commentRoute(String m, int id, Object? body) {
    final c = _comment(id);
    if (c == null) return json({'detail': 'Not found'}, 404);
    if (m == 'PATCH') {
      c['body'] = (body as Map)['body'];
      c['edited'] = true;
      return json(c);
    }
    comments.removeWhere((x) => x['id'] == id);
    for (final x in comments) {
      (x['replies'] as List).removeWhere((r) => r['id'] == id);
    }
    return http.Response('', 204);
  }

  http.Response _fileRoute(String m, String id) {
    if (m == 'DELETE') {
      files.removeWhere((f) => f['id'] == id);
      return http.Response('', 204);
    }
    return http.Response.bytes([1, 2, 3], 200);
  }

  /// Multipart upload to `/subjects/{sid}/files`.
  http.Response upload(http.BaseRequest req) {
    final id = 'f${files.length + 1}';
    files.add(fileJson(id, 'uploaded.pdf'));
    return json(files.last, 201);
  }
}

/// A [TasksEnv] over a fake server, plus the fakes the screens call out to.
typedef TasksFixture = ({
  TasksEnv env,
  FakeTasksServer server,
  FakeLive live,
  List<String> saved,
});

TasksFixture tasksFixture({
  FakeTasksServer? server,
  bool canCreate = true,
  PickedFile? picked,
}) {
  final fake = server ?? FakeTasksServer();
  final mock = MockClient.streaming((req, bodyStream) async {
    final bytes = await bodyStream.toBytes();
    final copy = http.Request(req.method, req.url)
      ..headers.addAll(req.headers)
      ..bodyBytes = bytes;
    final isUpload = req.url.path.endsWith('/files') && req.method == 'POST';
    final res = isUpload ? fake.upload(copy) : await fake.handle(copy);
    if (isUpload) {
      fake.calls.add(copy);
      fake.bodies.add(null);
    }
    return http.StreamedResponse(
      Stream.value(res.bodyBytes),
      res.statusCode,
      headers: res.headers,
    );
  });
  final client = ApiClient(
    baseUrl: 'http://x',
    store: MemoryTokenStore(),
    client: mock,
  )..setSession(access: 'tok', refresh: 'r');
  final live = FakeLive(client);
  final saved = <String>[];
  final env = TasksEnv(
    api: TasksApi(client, httpClient: mock),
    live: live,
    userId: 2,
    userName: 'Me',
    canCreate: canCreate,
    pickFile: () async => picked,
    saveFile:
        (Uint8List bytes, {required String name, String? mimeType}) async {
          saved.add(name);
        },
  );
  return (env: env, server: fake, live: live, saved: saved);
}
