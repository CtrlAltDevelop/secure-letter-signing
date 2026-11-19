import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:letter_signing/crm/crm_api.dart';
import 'package:letter_signing/crm/crm_env.dart';
import 'package:letter_signing/meetings/meetings_api.dart';
import 'package:letter_signing/meetings/meetings_env.dart';
import 'package:letter_signing/tasks/tasks_api.dart';
import 'package:letter_signing/tasks/tasks_env.dart';
import 'package:letter_signing/workspace/file_pick.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

import '../letters/fakes.dart';

const me = {'id': 2, 'full_name': 'Ali', 'email': 'a@x'};
const sara = {'id': 3, 'full_name': 'Sara', 'email': 's@x'};

Map<String, dynamic> customerJson(
  String id, {
  String name = 'Acme',
  String kind = 'company',
  String role = 'manager',
  String status = 'active',
  String mobile = '09120000000',
  List<int> labelIds = const [],
  List<Map<String, Object?>>? members,
}) => {
  'id': id,
  'subject_id': 'cs-$id',
  'kind': kind,
  'name': name,
  'legal_name': '',
  'national_id': '',
  'registration_no': '',
  'phone': '',
  'mobile': mobile,
  'email': '',
  'status': status,
  'owner_id': 2,
  'my_role': role,
  'label_ids': labelIds,
  'unseen': false,
  'address': {'text': 'Tehran'},
  'notes': {'text': 'VIP'},
  'owner': me,
  'members':
      members ??
      [
        {'user': me, 'role': 'manager'},
      ],
  'can': {
    'see': true,
    'comment': true,
    'label': role != 'viewer',
    'link': role != 'viewer',
    'event': role != 'viewer',
    'call': role != 'viewer',
    'edit': role == 'manager',
    'members': role == 'manager',
  },
};

/// A scripted in-memory CRM server; every request is recorded.
class FakeCrmServer {
  final List<Map<String, dynamic>> customers = [];
  final List<Map<String, dynamic>> events = [];
  final List<Map<String, dynamic>> calls = [];
  final List<Map<String, dynamic>> tasks = [];
  final List<http.Request> requests = [];
  final List<Object?> bodies = [];
  bool limitReached = false;

  /// Letters by id -> the customer ids each one is linked to.
  final Map<String, List<String>> letterLinks = {};
  Map<String, dynamic> importResult = {
    'created': 2,
    'skipped': 1,
    'errors': [
      {'row': 4, 'message': 'name is required'},
    ],
  };
  int _next = 100;

  Iterable<http.Request> where(String method, String part) =>
      requests.where((r) => r.method == method && r.url.path.contains(part));

  Object? lastBody(String method, String part) {
    for (var i = requests.length - 1; i >= 0; i--) {
      if (requests[i].method == method && requests[i].url.path.contains(part)) {
        return bodies[i];
      }
    }
    return null;
  }

  http.Response handle(http.Request req, Object? body) {
    requests.add(req);
    bodies.add(body);
    final path = req.url.path.replaceFirst('/api', '');
    final m = req.method;
    final b = body is Map ? body : const {};
    if (path == '/labels') {
      return json([
        {'id': 1, 'name': 'VIP', 'color': 4, 'scope': 'org', 'active': true},
      ]);
    }
    if (path == '/letters/directory') return json([me, sara]);
    if (path == '/letters' && m == 'GET') {
      return json([
        for (final id in letterLinks.keys) briefJson(id, title: 'Letter $id'),
      ]);
    }
    if (path.startsWith('/letters/') && path.endsWith('/customers')) {
      final id = path.split('/')[2];
      letterLinks[id] = [for (final r in b['customer_refs'] as List) '$r'];
      return json({'customer_refs': letterLinks[id]});
    }
    if (path.startsWith('/letters/')) {
      final id = path.split('/')[2];
      return json({
        ...detailJson(briefJson(id, title: 'Letter $id')),
        'customer_refs': letterLinks[id] ?? <String>[],
      });
    }
    if (path.endsWith('/letters') && path.startsWith('/customers/')) {
      final cid = path.split('/')[2];
      return json([
        for (final e in letterLinks.entries)
          if (e.value.contains(cid)) briefJson(e.key, title: 'Letter ${e.key}'),
      ]);
    }
    if (path == '/pins') return json(<Object>[]);
    if (path == '/bookmarks') return json(<Object>[]);
    if (path.startsWith('/subjects/')) return _subject(path, m);
    if (path == '/customers/import') return json(importResult, 201);
    if (path == '/customers' && m == 'GET') return json(customers);
    if (path == '/customers' && m == 'POST') {
      if (limitReached) return json({'detail': 'Customer limit reached'}, 409);
      final c = customerJson('c${_next++}', name: b['name'] as String);
      customers.add(c);
      return json(c, 201);
    }
    final seg = path.split('/');
    final c = customers.firstWhere((x) => x['id'] == seg[2]);
    final tail = seg.length > 3 ? seg[3] : '';
    if (tail == '') {
      if (m == 'PATCH') c.addAll(b.cast<String, dynamic>());
      return json(c);
    }
    if (tail == 'members') {
      c['members'] = [
        for (final x in body as List)
          {'user': (x as Map)['user_id'] == 3 ? sara : me, 'role': x['role']},
      ];
      return json(c);
    }
    return _sub(tail, seg, m, b, req.url.queryParameters['kind'] ?? '');
  }

  http.Response _sub(
    String tail,
    List<String> seg,
    String m,
    Map b,
    String kind,
  ) {
    switch (tail) {
      case 'events':
        if (m == 'POST') {
          final e = {
            'id': _next++,
            'kind': b['kind'],
            'summary': b['summary'],
            'at': '2026-05-01T10:00:00Z',
            'by': me,
            'ref_subject_id': null,
          };
          events.insert(0, e);
          return json(e, 201);
        }
        return json([
          for (final e in events)
            if (kind.isEmpty || e['kind'] == kind) e,
        ]);
      case 'calls':
        if (seg.length > 5) {
          final t = {'id': 'tk1', 'subject_id': 'ts-1', 'title': 'Follow up'};
          tasks.add(t);
          return json(t, 201);
        }
        if (m == 'POST') {
          final c = {
            'id': _next++,
            'direction': b['direction'],
            'contact_name': b['contact_name'],
            'summary': b['summary'],
            'at': '2026-05-01T10:00:00Z',
            'duration_s': b['duration_s'],
            'by': me,
          };
          calls.insert(0, c);
          return json(c, 201);
        }
        return json(calls);
      case 'tasks':
        return json(tasks);
      case 'history':
        return json(<Object>[]);
      default:
        return json(<Object>[]);
    }
  }

  http.Response _subject(String path, String m) {
    if (path.endsWith('/labels')) {
      return json({
        'label_ids': <int>[1],
      });
    }
    return json(<Object>[]);
  }
}

/// A [CrmEnv] over [server]; the finance/leads/chat panels are plain markers.
({CrmEnv env, FakeLive live}) crmEnv(
  FakeCrmServer server, {
  bool canImport = false,
  bool panels = false,
  FilePickFn? pick,
}) {
  final f = fakeApi(server.handle);
  final ws = WorkspaceApi(f.client, httpClient: f.api.httpClient);
  final live = FakeLive(f.client);
  final tasks = TasksEnv(
    api: TasksApi(f.client, httpClient: f.api.httpClient),
    live: live,
    userId: 2,
  );
  final env = CrmEnv(
    api: CrmApi(ws),
    live: live,
    userId: 2,
    tasks: tasks,
    meetings: MeetingsEnv(
      api: MeetingsApi(ws),
      live: live,
      userId: 2,
      tasks: tasks,
    ),
    letters: testEnv(f, live: live),
    canImport: canImport,
    financePanel: panels ? (_) => const Text('finance-panel') : null,
    leadsPanel: panels ? (_) => const Text('leads-panel') : null,
    pickFile: pick,
    saveFile: (Uint8List bytes, {required name, mimeType}) async {},
  );
  return (env: env, live: live);
}
