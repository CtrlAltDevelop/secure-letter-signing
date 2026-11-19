import 'package:http/http.dart' as http;
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/tasks/tasks_env.dart';

import '../tasks/task_fixtures.dart';
import 'fakes.dart';

Map<String, dynamic> v2Brief(
  String id, {
  String status = 'published',
  int no = 1,
  String title = 'T',
  String numberLabel = '',
  List<int> labelIds = const [],
  bool archived = false,
  int referrals = 0,
  int creator = 1,
}) => {
  ...briefJson(id, status: status, no: no, title: title, creator: creator),
  'subject_id': 'subj-$id',
  'label_ids': labelIds,
  'number_label': numberLabel,
  'referral_count': referrals,
  'archived': archived,
};

Map<String, dynamic> referralJson(
  int id, {
  String status = 'pending',
  Map<String, dynamic> to = me,
  Map<String, dynamic> from = bob,
  String note = '',
}) => {
  'id': id,
  'letter_id': 'L1',
  'from_user': from,
  'to_user': to,
  'note': {'text': note},
  'status': status,
  'response_note': {'text': ''},
  'created_at': '2026-01-01T00:00:00Z',
  'responded_at': null,
};

Map<String, dynamic> entryJson(
  String id, {
  String direction = 'in',
  String number = '1405/0001',
  String title = 'Entry',
  String party = '',
}) => {
  'id': id,
  'subject_id': 'es-$id',
  'direction': direction,
  'number': number,
  'jalali_year': 1405,
  'seq': 1,
  'registered_at': '2026-01-01T00:00:00Z',
  'registered_by': me,
  'title': title,
  'party_name': party,
  'party_ref': '',
  'letter_id': null,
  'summary': {'text': ''},
  'customer_refs': <String>[],
  'label_ids': <int>[],
  'active': true,
};

/// A scripted letters v2 server: lists by box, search, detail, referrals, linked tasks, paraph,
/// secretariat and the shared subject calls. Tests tweak the public state.
class FakeLettersServer {
  FakeLettersServer() {
    detail = detailJson(
      v2Brief('L1', title: 'Budget', no: 7),
      participants: [participantJson(const FakeUser(2, 'me@x.test'))],
    );
    detail['paraphs'] = <Map<String, dynamic>>[];
    detail['tasks'] = <Map<String, dynamic>>[];
    detail['customer_refs'] = <String>[];
  }

  late Map<String, dynamic> detail;
  List<Map<String, dynamic>> inbox = [v2Brief('L1', title: 'Budget', no: 7)];
  List<Map<String, dynamic>> outbox = [];
  List<Map<String, dynamic>> archive = [];
  List<Map<String, dynamic>> searchRows = [];
  final List<Map<String, dynamic>> referrals = [];
  final List<Map<String, dynamic>> entries = [];
  final List<Map<String, dynamic>> pickableTasks = [
    briefTask('t1', title: 'Pay invoice'),
    briefTask('t2', title: 'File copy'),
  ];
  final List<Map<String, dynamic>> labels = [
    {'id': 3, 'name': 'Urgent', 'color': 4, 'scope': 'org'},
  ];
  final List<http.Request> calls = [];
  final List<Object?> bodies = [];
  List<Map<String, dynamic>> sessions = [
    sessionJson('S1', device: 'laptop', current: true, biometric: true),
  ];
  Map<String, dynamic> certificate = {
    'signatures': <Map<String, dynamic>>[],
    'all_verified': true,
    'paraphs': <Map<String, dynamic>>[],
    'paraphs_verified': true,
  };

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
    if (path == '/letters' && m == 'GET') return _list(req.url);
    if (path == '/letters/search') return json(searchRows);
    if (path == '/labels') return json(labels);
    if (path == '/letters/directory') return json([bobDir, meDir]);
    if (path == '/me/sessions') return json(sessions);
    if (path == '/me/letterhead') return json({});
    if (path == '/tasks') return json(pickableTasks);
    if (path.startsWith('/secretariat')) return _secretariat(path, m, body);
    if (path.startsWith('/subjects/')) return _subject(path, m, body);
    if (path.startsWith('/referrals/')) return _respond(path, body);
    return _letter(path, m, body);
  }

  static const bobDir = {
    'id': 3,
    'email': 'bob@x.test',
    'full_name': 'Bob',
    'permissions': ['letter.see'],
  };
  static const meDir = {
    'id': 2,
    'email': 'me@x.test',
    'full_name': 'Me',
    'permissions': ['letter.see'],
  };

  http.Response _list(Uri url) {
    final box = url.queryParameters['box'] ?? 'all';
    return json(switch (box) {
      'inbox' => inbox,
      'outbox' => outbox,
      'archive' => archive,
      _ => [...inbox, ...outbox],
    });
  }

  http.Response _subject(String path, String m, Object? body) {
    if (path.endsWith('/labels') && m == 'PUT') return json(body);
    if (path.endsWith('/files')) return json(<Object>[]);
    return json(<Object>[]);
  }

  http.Response _respond(String path, Object? body) {
    final id = int.parse(path.split('/')[2]);
    final r = referrals.firstWhere((e) => e['id'] == id);
    r['status'] = (body as Map)['status'];
    return json(r);
  }

  http.Response _secretariat(String path, String m, Object? body) {
    final seg = path.split('/');
    if (seg.length == 3 && m == 'GET') return json(entries);
    if (seg.length == 3 && m == 'POST') {
      final b = body as Map;
      final e = entryJson(
        'e${entries.length + 1}',
        direction: b['direction'] as String,
        title: b['title'] as String,
        party: b['party_name'] as String,
      );
      entries.add(e);
      return json(e, 201);
    }
    final e = entries.firstWhere((x) => x['id'] == seg[3]);
    if (m == 'PATCH') {
      e['title'] = (body as Map)['title'];
    }
    return json(e);
  }

  http.Response _letter(String path, String m, Object? body) {
    final seg = path.split('/');
    final tail = seg.length > 3 ? seg.sublist(3).join('/') : '';
    if (tail.isEmpty && m == 'GET') return json(detail);
    switch (tail) {
      case 'archive':
        final brief = v2Brief(
          'L1',
          archived: (body as Map)['archived'] == true,
        );
        return json(brief);
      case 'referrals':
        return json(referrals);
      case 'refer':
        final b = body as Map;
        final made = [
          for (final id in (b['user_ids'] as List).cast<int>())
            referralJson(
              100 + referrals.length,
              to: id == 3 ? bob : me,
              from: me,
              note: b['note'] as String,
            ),
        ];
        referrals.addAll(made);
        return json(made, 201);
      case 'tasks':
        return _tasks(m, body);
      case 'paraph':
        return _paraph('pin');
      case 'paraph-biometric':
        return _paraph('biometric');
      case 'certificate':
        return json(certificate);
      case 'opened':
        return json({'detail': 'ok'});
    }
    if (tail.startsWith('tasks/') && m == 'DELETE') {
      (detail['tasks'] as List).removeWhere(
        (t) => t['id'] == tail.substring(6),
      );
      return http.Response('', 204);
    }
    return json({});
  }

  http.Response _tasks(String m, Object? body) {
    if (m == 'POST') {
      final id = (body as Map)['task_id'] as String;
      final t = pickableTasks.firstWhere(
        (x) => x['id'] == id,
        orElse: () => briefTask(id, title: 'Created'),
      );
      (detail['tasks'] as List).add(t);
      return json(t, 201);
    }
    return json(detail['tasks']);
  }

  http.Response _paraph(String method) {
    final p = {
      'signer_id': 2,
      'signer_name': 'Me',
      'method': method,
      'device_name': 'laptop',
      'paraphed_at': '2026-01-02T03:04:05Z',
      'seal': 'c2VhbA==',
      'payload': <String, dynamic>{},
    };
    (detail['paraphs'] as List).add(p);
    return json(p, 201);
  }
}

/// A [LettersEnv] over [server], with a Tasks env for the task screens.
LettersEnv v2Env(
  FakeLettersServer server, {
  bool secretariat = false,
  TasksFixture? tasks,
}) {
  final f = fakeApi(server.handle);
  final env = LettersEnv(
    api: f.api,
    live: FakeLive(f.client),
    userId: 2,
    biometrics: FakeBiometrics(),
    canSecretariat: secretariat,
    sessionId: () => 'S1',
  );
  if (tasks != null) {
    final TasksEnv t = tasks.env;
    env.tasksResolver = () => t;
  }
  return env;
}
