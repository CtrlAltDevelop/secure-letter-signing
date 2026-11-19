import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/projects/projects_env.dart';
import 'package:letter_signing/tasks/tasks_api.dart';
import 'package:letter_signing/tasks/tasks_env.dart';

import '../letters/fakes.dart';
import '../tasks/task_fixtures.dart';

Map<String, dynamic> columnJson(
  int id,
  String title, {
  String kind = 'doing',
}) => {
  'id': id,
  'title': title,
  'kind': kind,
  'rank': id * 100,
  'task_count': 0,
};

Map<String, dynamic> projectBrief(
  String id, {
  String name = 'Alpha',
  String status = 'active',
  int? groupId,
  String myRole = 'manager',
}) => {
  'id': id,
  'subject_id': 'ps-$id',
  'name': name,
  'color': 1,
  'status': status,
  'group_id': groupId,
  'owner_id': 2,
  'progress': 40,
  'start_date': '2026-03-21',
  'end_date': '2026-06-21',
  'my_role': myRole,
  'member_count': 3,
  'updated_at': '2026-01-01T00:00:00Z',
};

/// A board task: a brief task with column and rank.
Map<String, dynamic> boardTask(
  String id,
  int column,
  int rank, {
  String title = 'Task',
  String status = 'open',
  String? dueAt,
}) => {
  ...briefTask(id, title: title, status: status, dueAt: dueAt),
  'project_id': 'p1',
  'column_id': column,
  'rank': rank,
};

/// An in-memory projects server layered over [FakeTasksServer] (tasks, labels, comments).
class FakeProjectsServer {
  FakeProjectsServer({FakeTasksServer? tasks})
    : tasks = tasks ?? FakeTasksServer() {
    projects.add(projectBrief('p1'));
  }

  final FakeTasksServer tasks;
  final List<Map<String, dynamic>> projects = [];
  final List<Map<String, dynamic>> groups = [];
  final List<Map<String, dynamic>> reminders = [];
  final List<Map<String, dynamic>> projectFiles = [];
  List<Map<String, dynamic>> columns = [
    columnJson(1, 'To do', kind: 'todo'),
    columnJson(2, 'Doing'),
    columnJson(3, 'Done', kind: 'done'),
  ];
  List<Map<String, dynamic>> board = [];
  List<Map<String, dynamic>> calendar = [];
  final List<http.BaseRequest> calls = [];
  final List<Object?> bodies = [];

  /// Status for the next `move` request (then back to normal).
  int? failMove;

  /// False makes `/files` and `/copy` answer 404 like an older server.
  bool optionalEndpoints = true;
  int _next = 900;

  Object? lastBody(String method, String part) {
    for (var i = calls.length - 1; i >= 0; i--) {
      if (calls[i].method == method && calls[i].url.path.contains(part)) {
        return bodies[i];
      }
    }
    return null;
  }

  Iterable<http.BaseRequest> where(String method, String part) =>
      calls.where((r) => r.method == method && r.url.path.contains(part));

  Map<String, dynamic> detail(String id) => {
    ...projects.firstWhere((p) => p['id'] == id),
    'description': {'text': ''},
    'owner': me,
    'members': [
      {'user': me, 'role': 'manager'},
      {'user': bob, 'role': 'member'},
    ],
    'columns': columns,
    'can': {
      'see': true,
      'comment': true,
      'label': true,
      'edit': true,
      'moderate': true,
      'create_task': true,
    },
    'created_at': '2026-01-01T00:00:00Z',
  };

  http.Response handle(http.BaseRequest req, Object? body) {
    calls.add(req);
    bodies.add(body);
    final path = req.url.path.replaceFirst('/api', '');
    final m = req.method;
    if (path == '/projects') {
      if (m == 'POST') return _create(body as Map);
      return json(projects);
    }
    if (path == '/project-groups') return _groups(m, body);
    if (path.startsWith('/project-groups/')) return _patchGroup(path, body);
    if (path.startsWith('/projects/')) {
      return _project(m, path.split('/'), body, req.url);
    }
    if (path.endsWith('/move') || path.endsWith('/copy')) {
      return _taskMove(path, body);
    }
    if (path.endsWith('/reminders')) return _reminders(m, body);
    if (path.startsWith('/reminders/')) {
      reminders.removeWhere((r) => '${r['id']}' == path.split('/').last);
      return http.Response('', 204);
    }
    if (path == '/labels' && m == 'POST') return _label(body as Map);
    if (path.startsWith('/labels/')) return _patchLabel(path, body as Map);
    return json({'detail': 'Not found'}, 404);
  }

  http.Response _create(Map body) {
    final p = projectBrief('p${_next++}', name: body['name'] as String);
    projects.add(p);
    return json(detail(p['id'] as String), 201);
  }

  http.Response _groups(String m, Object? body) {
    if (m == 'POST') {
      final b = body as Map;
      final g = {
        'id': groups.length + 1,
        'name': b['name'],
        'scope': b['scope'],
        'rank': 1,
        'active': true,
      };
      groups.add(g);
      return json(g, 201);
    }
    return json(groups);
  }

  http.Response _patchGroup(String path, Object? body) {
    final g = groups.firstWhere((x) => '${x['id']}' == path.split('/').last);
    g.addAll((body as Map).cast<String, dynamic>());
    return json(g);
  }

  http.Response _project(String m, List<String> seg, Object? body, Uri url) {
    final id = seg[2];
    final sub = seg.length > 3 ? seg[3] : '';
    if (sub == 'tasks') {
      final view = url.queryParameters['view'];
      return json(
        view == 'board'
            ? {'view': 'board', 'columns': _boardJson()}
            : {
                'view': view,
                'tasks': view == 'calendar' ? calendar : tasks.tasks,
              },
      );
    }
    if (sub == 'files') {
      if (!optionalEndpoints) return json({'detail': 'Not found'}, 404);
      final type = url.queryParameters['type'] ?? '';
      return json([
        for (final f in projectFiles)
          if (type.isEmpty || '${f['content_type']}'.startsWith('$type/')) f,
      ]);
    }
    if (sub == 'copy') {
      if (!optionalEndpoints) return json({'detail': 'Not found'}, 404);
      final copy = projectBrief(
        'p${_next++}',
        name: (body as Map)['name'] as String,
      );
      projects.add(copy);
      return json(detail(copy['id'] as String), 201);
    }
    if (sub == 'columns') return _columns(m, seg, body);
    if (m == 'PATCH') {
      projects
          .firstWhere((p) => p['id'] == id)
          .addAll((body as Map).cast<String, dynamic>()..remove('description'));
    }
    return json(detail(id));
  }

  List<Map<String, dynamic>> _boardJson() => [
    for (final c in columns)
      {
        ...c,
        'tasks': [
          for (final t in board)
            if (t['column_id'] == c['id']) t,
        ]..sort((a, b) => (a['rank'] as int).compareTo(b['rank'] as int)),
      },
  ];

  http.Response _columns(String m, List<String> seg, Object? body) {
    final b = body is Map ? body : const {};
    if (m == 'POST') {
      columns = [
        ...columns,
        columnJson(columns.length + 10, b['title'] as String),
      ];
    } else if (seg.length > 4 && seg[4] == 'order') {
      final ids = (b['ids'] as List).cast<int>();
      columns = [for (final i in ids) columns.firstWhere((c) => c['id'] == i)];
    } else if (m == 'PATCH') {
      final c = columns.firstWhere((x) => '${x['id']}' == seg[4]);
      if (b['title'] != null) c['title'] = b['title'];
      if (b['active'] == false) {
        columns = [
          for (final x in columns)
            if (x != c) x,
        ];
      }
    }
    return json(columns, m == 'POST' ? 201 : 200);
  }

  http.Response _taskMove(String path, Object? body) {
    final id = path.split('/')[2];
    final b = body as Map;
    if (path.endsWith('/copy')) {
      return json(fullTask('copy-$id', title: 'Copy'), 201);
    }
    final fail = failMove;
    if (fail != null) {
      failMove = null;
      return json({'detail': 'boom'}, fail);
    }
    final t = board.where((x) => x['id'] == id).firstOrNull;
    if (t != null) {
      board.remove(t);
      t['column_id'] = b['column_id'];
      final before = board.indexWhere((x) => x['id'] == b['before_id']);
      board.insert(before < 0 ? board.length : before, t);
      for (var i = 0; i < board.length; i++) {
        board[i]['rank'] = (i + 1) * 100;
      }
    }
    final out = fullTask(id);
    out['project_id'] = b['project_id'];
    out['column_id'] = b['column_id'];
    out['rank'] = t?['rank'] ?? 0;
    return json(out);
  }

  http.Response _reminders(String m, Object? body) {
    if (m == 'POST') {
      final b = body as Map;
      final r = {
        'id': reminders.length + 1,
        'subject_id': 's',
        'at': b['at'],
        'rule': b['rule'],
        'last_fired_at': null,
      };
      reminders.add(r);
      return json(r, 201);
    }
    return json(reminders);
  }

  http.Response _label(Map body) {
    if (tasks.labels.any((l) => l['name'] == body['name'])) {
      return json({'detail': 'dup'}, 409);
    }
    final l = {
      'id': tasks.labels.length + 1,
      'name': body['name'],
      'color': body['color'],
      'scope': body['scope'],
      'active': true,
    };
    tasks.labels.add(l);
    return json(l, 201);
  }

  http.Response _patchLabel(String path, Map body) {
    final l = tasks.labels.firstWhere(
      (x) => '${x['id']}' == path.split('/').last,
    );
    l.addAll(body.cast<String, dynamic>());
    return json(l);
  }
}

typedef ProjectsFixture = ({
  ProjectsEnv env,
  FakeProjectsServer server,
  FakeLive live,
});

ProjectsFixture projectsFixture({
  FakeProjectsServer? server,
  bool canCreate = true,
  bool isManager = false,
}) {
  final fake = server ?? FakeProjectsServer();
  final mock = MockClient.streaming((req, bodyStream) async {
    final bytes = await bodyStream.toBytes();
    final copy = http.Request(req.method, req.url)
      ..headers.addAll(req.headers)
      ..bodyBytes = bytes;
    final path = req.url.path.replaceFirst('/api', '');
    final mine =
        path.startsWith('/project') ||
        path.endsWith('/move') ||
        path.endsWith('/copy') ||
        path.contains('reminders') ||
        (path.startsWith('/labels') && req.method != 'GET');
    final body = bytes.isEmpty ? null : jsonDecode(utf8.decode(bytes));
    final res = mine ? fake.handle(copy, body) : await fake.tasks.handle(copy);
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
  final tasksEnv = TasksEnv(
    api: TasksApi(client, httpClient: mock),
    live: live,
    userId: 2,
    userName: 'Me',
  );
  final env = ProjectsEnv(
    api: tasksEnv.projects,
    tasks: tasksEnv,
    live: live,
    userId: 2,
    canCreate: canCreate,
    isManager: isManager,
  );
  return (env: env, server: fake, live: live);
}
