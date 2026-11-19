import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:letter_signing/sales/sales_api.dart';
import 'package:letter_signing/sales/sales_env.dart';
import 'package:letter_signing/workspace/file_pick.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

import '../letters/fakes.dart';

Map<String, dynamic> leadJson(
  String id, {
  String title = 'Deal',
  int value = 10000000,
  int probability = 50,
  String status = 'open',
  bool canEdit = true,
  String? customerName,
  String lostReason = '',
  List<int> labelIds = const [],
}) => {
  'id': id,
  'subject_id': 'ls-$id',
  'customer_id': customerName == null ? null : 'c1',
  'customer_name': customerName,
  'title': title,
  'value': value,
  'probability': probability,
  'weighted_value': value * probability ~/ 100,
  'status': status,
  'owner': {'id': 2, 'full_name': 'Ali', 'email': 'a@x'},
  'description': {'text': ''},
  'closed_at': null,
  'lost_reason': status == 'lost' ? {'text': lostReason} : null,
  'created_by': {'id': 2, 'full_name': 'Ali', 'email': 'a@x'},
  'created_at': '2026-05-01T00:00:00Z',
  'updated_at': '2026-05-01T00:00:00Z',
  'label_ids': labelIds,
  'can_edit': canEdit,
};

/// A scripted in-memory sales server; every request is recorded.
class FakeSalesServer {
  final List<Map<String, dynamic>> leads = [];
  final List<Map<String, dynamic>> files = [];
  final List<Map<String, dynamic>> labels = [
    {'id': 1, 'name': 'Hot', 'color': 4, 'scope': 'org', 'active': true},
  ];
  final List<http.Request> calls = [];
  final List<Object?> bodies = [];
  int _next = 100;

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
    if (path == '/labels') return json(labels);
    if (path == '/letters/directory') {
      return json([
        {'id': 2, 'full_name': 'Ali', 'email': 'a@x'},
        {'id': 3, 'full_name': 'Sara', 'email': 's@x'},
      ]);
    }
    if (path.startsWith('/subjects/')) return _subject(path, m);
    if (path == '/sales/leads' && m == 'GET') return _list(req.url);
    if (path == '/sales/leads' && m == 'POST') return _create(body as Map);
    if (path == '/sales/summary') return _summary();
    if (path.startsWith('/customers/')) return json(leads);
    return _lead(path.split('/'), m, body is Map ? body : const {});
  }

  http.Response _subject(String path, String m) {
    if (path.endsWith('/files') && m == 'POST') {
      final f = {
        'id': 'f${_next++}',
        'name': 'offer.pdf',
        'content_type': 'application/pdf',
        'size': 3,
        'uploaded_by': {'id': 2, 'full_name': 'Ali', 'email': 'a@x'},
      };
      files.add(f);
      return json(f, 201);
    }
    if (path.endsWith('/labels')) return json({'label_ids': <int>[]});
    if (path.endsWith('/files')) return json(files);
    return json(<Object>[]);
  }

  http.Response _list(Uri url) {
    final q = url.queryParameters;
    final bucket = q['probability_bucket'] ?? '';
    final rows = [
      for (final l in leads)
        if ((q['status'] ?? '').isEmpty ||
            q['status']!.split(',').contains(l['status']))
          if (bucket.isEmpty || _inBucket(l['probability'] as int, bucket)) l,
    ];
    return json(rows);
  }

  bool _inBucket(int p, String bucket) {
    final parts = bucket.split('-').map(int.parse).toList();
    return p >= parts[0] && p <= parts[1];
  }

  http.Response _create(Map body) {
    final l = leadJson(
      'l${_next++}',
      title: body['title'] as String,
      value: body['value'] as int,
      probability: body['probability'] as int,
    );
    leads.add(l);
    return json(l, 201);
  }

  http.Response _lead(List<String> seg, String m, Map body) {
    final l = leads.firstWhere((x) => x['id'] == seg[3]);
    final tail = seg.length > 4 ? seg[4] : '';
    if (tail == 'win') l['status'] = 'won';
    if (tail == 'reopen') l['status'] = 'open';
    if (tail == 'lose') {
      l['status'] = 'lost';
      l['lost_reason'] = {'text': body['reason']};
    }
    if (tail == '' && m == 'PATCH') {
      for (final e in body.entries) {
        l[e.key as String] = e.value;
      }
    }
    return json(l);
  }

  http.Response _summary() => json({
    'won': {'count': 2, 'value': 8000000},
    'lost': {'count': 1, 'value': 1000000},
    'open': {'count': 3, 'value': 30000000, 'weighted': 12000000},
    'by_status': {'open': 3, 'won': 2, 'lost': 1},
    'by_probability': [
      {
        'bucket': '0-24',
        'min': 0,
        'max': 24,
        'count': 1,
        'value': 5,
        'weighted': 1,
      },
      {
        'bucket': '75-100',
        'min': 75,
        'max': 100,
        'count': 2,
        'value': 9,
        'weighted': 8,
      },
    ],
    'won_by_month': [
      {
        'period': '2026-05',
        'jalali_year': 1405,
        'jalali_month': 2,
        'count': 2,
        'value': 8000000,
      },
    ],
    'by_owner': <Object>[],
  });
}

({SalesEnv env, FakeLive live}) salesEnv(
  FakeSalesServer server, {
  FilePickFn? pick,
}) {
  final f = fakeApi(server.handle);
  final live = FakeLive(f.client);
  final env = SalesEnv(
    api: SalesApi(WorkspaceApi(f.client, httpClient: f.api.httpClient)),
    live: live,
    userId: 2,
    pickFile: pick,
    saveFile: (bytes, {required name, mimeType}) async {},
  );
  return (env: env, live: live);
}

Future<PickedFile?> pickPdf() async => PickedFile(
  name: 'offer.pdf',
  bytes: Uint8List.fromList([1, 2, 3]),
  contentType: 'application/pdf',
);
