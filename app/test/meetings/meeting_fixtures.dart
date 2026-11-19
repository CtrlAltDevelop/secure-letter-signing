import 'package:http/http.dart' as http;
import 'package:letter_signing/meetings/meetings_api.dart';
import 'package:letter_signing/meetings/meetings_env.dart';
import 'package:letter_signing/workspace/file_pick.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

import '../letters/fakes.dart';
import '../tasks/task_fixtures.dart';

Map<String, dynamic> canFlags({
  bool manage = true,
  bool record = true,
  bool run = true,
  bool chair = true,
  bool sign = false,
  bool comment = true,
}) => {
  'manage': manage,
  'record': record,
  'run': run,
  'chair': chair,
  'sign': sign,
  'comment': comment,
};

Map<String, dynamic> attendeeJson(
  int id, {
  Map<String, dynamic>? user = me,
  String guest = '',
  String role = 'member',
  String attendance = 'unknown',
}) => {
  'id': id,
  'user': user,
  'guest_name': guest,
  'role': role,
  'attendance': attendance,
};

Map<String, dynamic> resolutionJson(
  int id,
  String text, {
  String status = 'open',
  List<int> owners = const [],
  String? taskId,
  String? due,
}) => {
  'id': id,
  'text': text,
  'due_at': due,
  'status': status,
  'owner_ids': owners,
  'task_id': taskId,
  'task_status': taskId == null ? null : 'open',
  'task_progress': taskId == null ? null : 40,
  'created_at': '2026-01-01T00:00:00Z',
};

Map<String, dynamic> meetingSignature(
  int id, {
  Map<String, dynamic> user = me,
  String decision = 'approved',
  bool stale = false,
  bool valid = true,
}) => {
  'id': id,
  'user': user,
  'decision': decision,
  'note': '',
  'method': 'pin',
  'revision': 1,
  'stale': stale,
  'valid': valid,
  'created_at': '2026-01-02T03:04:05Z',
};

Map<String, dynamic> meetingBrief(
  String id, {
  String title = 'Weekly sync',
  String status = 'scheduled',
  String kind = 'simple',
  String? startsAt = '2999-03-21T08:30:00Z',
  String location = 'Room 1',
}) => {
  'id': id,
  'subject_id': 'ms-$id',
  'title': title,
  'kind': kind,
  'status': status,
  'location': location,
  'starts_at': startsAt,
  'ends_at': null,
  'project_id': null,
  'creator_id': 2,
  'my_role': 'chair',
  'attendee_count': 2,
  'resolutions': {'done': 0, 'total': 0},
  'label_ids': <int>[],
  'unseen': false,
  'revision': 1,
  'updated_at': '2026-01-01T00:00:00Z',
};

Map<String, dynamic> meetingFull(
  String id, {
  String title = 'Weekly sync',
  String status = 'scheduled',
  String kind = 'simple',
  Map<String, dynamic>? can,
  List<Map<String, dynamic>>? attendees,
  List<Map<String, dynamic>> resolutions = const [],
  List<Map<String, dynamic>> signatures = const [],
  String description = '',
}) => {
  ...meetingBrief(id, title: title, status: status, kind: kind),
  'description': {'text': description},
  'creator': me,
  'attendees':
      attendees ??
      [
        attendeeJson(1, role: 'chair'),
        attendeeJson(2, user: bob, role: 'member'),
      ],
  'resolution_items': [...resolutions],
  'signatures': [...signatures],
  'template_id': null,
  'content_hash': 'abc',
  'all_signed': false,
  'can': can ?? canFlags(),
  'created_at': '2026-01-01T00:00:00Z',
};

/// A scripted in-memory meetings server. Tests tweak [meeting] and [list]; every request is
/// recorded in [calls] / [bodies].
class FakeMeetingsServer {
  FakeMeetingsServer() {
    meeting = meetingFull('m1');
    list = [meetingBrief('m1')];
  }

  late Map<String, dynamic> meeting;
  late List<Map<String, dynamic>> list;
  final List<Map<String, dynamic>> templates = [];
  final List<Map<String, dynamic>> projects = [];
  final List<http.Request> calls = [];
  final List<Object?> bodies = [];
  List<Map<String, dynamic>> sessions = [
    sessionJson('S1', device: 'laptop', current: true, biometric: true),
  ];

  /// Status code for the next meeting write only.
  int? failNext;
  String failDetail = 'boom';

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
    if (path == '/letters/directory') return json([me, bob, carol]);
    if (path == '/labels') return json(<Object>[]);
    if (path == '/me/sessions') return json(sessions);
    if (path == '/me/letterhead') return json(<String, dynamic>{});
    if (path == '/projects') return json(projects);
    if (path.startsWith('/subjects/')) return json(<Object>[]);
    if (path.startsWith('/meeting-templates')) return _templates(path, m, body);
    if (path == '/meetings' && m == 'GET') return json(list);
    if (path == '/meetings' && m == 'POST') return _create(body as Map);
    final fail = failNext;
    if (fail != null && m != 'GET') {
      failNext = null;
      return json({'detail': failDetail}, fail);
    }
    return _meeting(path.split('/'), m, body);
  }

  http.Response _create(Map body) {
    meeting = meetingFull(
      'm2',
      title: body['title'] as String,
      status: body['status'] as String,
      kind: body['kind'] as String,
    );
    return json(meeting, 201);
  }

  http.Response _meeting(List<String> seg, String m, Object? body) {
    final tail = seg.length > 3 ? seg.sublist(3).join('/') : '';
    final map = body is Map ? body : const {};
    if (tail.startsWith('resolutions/')) return _editResolution(tail, map);
    switch (tail) {
      case '':
        if (m == 'PATCH') _patch(map);
      case 'schedule':
        meeting['status'] = 'scheduled';
      case 'hold':
        meeting['status'] = 'held';
      case 'close':
        meeting['status'] = 'closed';
      case 'reopen':
        meeting['status'] = 'held';
        meeting['revision'] = (meeting['revision'] as int) + 1;
      case 'cancel':
        meeting['status'] = 'cancelled';
      case 'attendees':
        _setAttendees(body as List);
      case 'attendance':
        _attendance(map);
      case 'resolutions':
        return _addResolution(map);
      case 'sign':
        _sign(map);
      case 'sign-biometric':
        _sign(map);
      case 'remind':
        return json({'reminders': 2});
      case 'sms':
        return json({'sent': 2, 'without_phone': 1});
    }
    return json(meeting);
  }

  void _setAttendees(List body) {
    meeting['attendees'] = [
      for (final (i, a) in body.indexed)
        attendeeJson(
          10 + i,
          user: (a as Map)['user_id'] == null
              ? null
              : (a['user_id'] == 2 ? me : bob),
          guest: '${a['guest_name'] ?? ''}',
          role: a['role'] as String,
        ),
    ];
  }

  void _patch(Map body) {
    for (final e in body.entries) {
      meeting[e.key as String] = e.value;
    }
  }

  void _attendance(Map body) {
    final list = (meeting['attendees'] as List).cast<Map<String, dynamic>>();
    list.firstWhere((a) => a['id'] == body['attendee_id'])['attendance'] =
        body['attendance'];
  }

  http.Response _addResolution(Map body) {
    final items = (meeting['resolution_items'] as List).cast<Map>();
    final owners = (body['owner_ids'] as List).cast<int>();
    final r = resolutionJson(
      50 + items.length,
      body['text'] as String,
      owners: owners,
      taskId: owners.isEmpty ? null : 'tsk-1',
    );
    items.add(r);
    return json(r, 201);
  }

  http.Response _editResolution(String tail, Map body) {
    final id = int.parse(tail.split('/')[1]);
    final items = (meeting['resolution_items'] as List).cast<Map>();
    final r = items.firstWhere((x) => x['id'] == id);
    if (body['active'] == false) {
      items.remove(r);
    } else {
      if (body['text'] != null) r['text'] = body['text'];
      if (body['owner_ids'] != null) r['owner_ids'] = body['owner_ids'];
    }
    return json(r);
  }

  void _sign(Map body) {
    (meeting['signatures'] as List).add(
      meetingSignature(90, decision: body['decision'] as String),
    );
  }

  http.Response _templates(String path, String m, Object? body) {
    if (m == 'GET') return json(templates);
    if (m == 'POST') {
      final b = body as Map;
      final t = {
        'id': 7 + templates.length,
        'name': b['name'],
        'scope': b['scope'],
        'owner_id': 2,
        'data': b['data'],
        'active': true,
      };
      templates.add(t);
      return json(t, 201);
    }
    final id = int.parse(path.split('/').last);
    final t = templates.firstWhere((x) => x['id'] == id);
    for (final e in (body as Map).entries) {
      t[e.key as String] = e.value;
    }
    return json(t);
  }
}

/// A [MeetingsEnv] over [server]; the Tasks env comes from the tasks fixture.
({MeetingsEnv env, TasksFixture tasks, FakeLive live}) meetingsEnv(
  FakeMeetingsServer server, {
  bool isManager = false,
  FakeBiometrics? biometrics,
  FilePickFn? pick,
}) {
  final f = fakeApi(server.handle);
  final tasks = tasksFixture();
  final live = FakeLive(f.client);
  final env = MeetingsEnv(
    api: MeetingsApi(WorkspaceApi(f.client, httpClient: f.api.httpClient)),
    live: live,
    userId: 2,
    tasks: tasks.env,
    isManager: isManager,
    biometrics: biometrics ?? FakeBiometrics(),
    pickFile: pick,
  );
  return (env: env, tasks: tasks, live: live);
}
