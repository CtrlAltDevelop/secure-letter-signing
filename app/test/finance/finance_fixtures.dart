import 'package:http/http.dart' as http;
import 'package:letter_signing/finance/finance_api.dart';
import 'package:letter_signing/finance/finance_env.dart';
import 'package:letter_signing/workspace/file_pick.dart';
import 'package:letter_signing/workspace/workspace_api.dart';
import 'package:flutter/foundation.dart';

import '../letters/fakes.dart';

Map<String, dynamic> docJson(
  String id, {
  String kind = 'cash',
  String direction = 'receipt',
  int amount = 1500000,
  String date = '2026-05-01',
  String? due,
  String status = 'confirmed',
  bool overdue = false,
  String description = '',
  String? customerName,
  List<int> labelIds = const [],
  String voidReason = '',
}) => {
  'id': id,
  'subject_id': 'fs-$id',
  'customer_id': customerName == null ? null : 'c1',
  'customer_name': customerName,
  'kind': kind,
  'direction': direction,
  'amount': amount,
  'date': date,
  'due_date': due,
  'description': {'text': description},
  'status': status,
  'overdue': overdue,
  'created_by': {'id': 2, 'full_name': 'Ali', 'email': 'a@x'},
  'voided_by': status == 'void'
      ? {'id': 2, 'full_name': 'Ali', 'email': 'a@x'}
      : null,
  'voided_at': null,
  'void_reason': status == 'void' ? {'text': voidReason} : null,
  'label_ids': labelIds,
  'file_count': 0,
};

Map<String, dynamic> statsJson({
  int receipts = 0,
  int payments = 0,
  int probable = 0,
  int overdue = 0,
}) => {
  'confirmed_receipts': receipts,
  'confirmed_payments': payments,
  'probable_receipts': probable,
  'probable_payments': 0,
  'overdue_receipts': overdue,
  'overdue_payments': 0,
  'net': receipts - payments,
  'projected_net': receipts - payments + probable,
};

/// A scripted in-memory finance server; every request is recorded.
class FakeFinanceServer {
  final List<Map<String, dynamic>> docs = [];
  final List<Map<String, dynamic>> files = [];
  final List<Map<String, dynamic>> labels = [
    {'id': 1, 'name': 'Rent', 'color': 1, 'scope': 'org', 'active': true},
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

  Map<String, dynamic> _find(String id) =>
      docs.firstWhere((d) => d['id'] == id);

  http.Response handle(http.Request req, Object? body) {
    calls.add(req);
    bodies.add(body);
    final path = req.url.path.replaceFirst('/api', '');
    final m = req.method;
    if (path == '/labels') return json(labels);
    if (path.startsWith('/subjects/')) return _subject(path, m);
    if (path == '/finance/docs' && m == 'GET') return _list(req.url);
    if (path == '/finance/docs' && m == 'POST') return _create(body as Map);
    if (path == '/finance/summary') return _summary(req.url);
    if (path.startsWith('/customers/')) return _customer();
    return _doc(path.split('/'), m, body is Map ? body : const {});
  }

  http.Response _subject(String path, String m) {
    if (path.endsWith('/files') && m == 'POST') {
      final f = {
        'id': 'f${_next++}',
        'name': 'cheque.pdf',
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
    final rows = [
      for (final d in docs)
        if ((q['direction'] ?? '').isEmpty || d['direction'] == q['direction'])
          if ((q['status'] ?? '').isEmpty ||
              q['status']!.split(',').contains(d['status']))
            if ((q['q'] ?? '').isEmpty ||
                '${(d['description'] as Map)['text']}'.contains(q['q']!))
              d,
    ];
    return json(rows);
  }

  http.Response _create(Map body) {
    final d = docJson(
      'd${_next++}',
      kind: body['kind'] as String,
      direction: body['direction'] as String,
      amount: body['amount'] as int,
      date: body['date'] as String,
      due: body['due_date'] as String?,
      status: body['kind'] == 'cash' ? 'confirmed' : 'pending',
      description: (body['description'] as Map)['text'] as String,
    );
    docs.add(d);
    return json(d, 201);
  }

  http.Response _doc(List<String> seg, String m, Map body) {
    final d = _find(seg[3]);
    final tail = seg.length > 4 ? seg[4] : '';
    if (tail == 'confirm') d['status'] = 'confirmed';
    if (tail == 'void') {
      d['status'] = 'void';
      d['void_reason'] = {'text': body['reason']};
    }
    if (tail == '' && m == 'PATCH') {
      for (final e in body.entries) {
        d[e.key as String] = e.key == 'description' ? e.value : e.value;
      }
    }
    return json(d);
  }

  http.Response _summary(Uri url) {
    final yearly = url.queryParameters['group_by'] == 'year';
    final buckets = yearly
        ? [
            {
              'period': '2026',
              'start': '2026-01-01',
              'end': '2026-12-31',
              'jalali_year': 1405,
              'jalali_month': null,
              ...statsJson(receipts: 5000000, payments: 2000000),
            },
          ]
        : [
            {
              'period': '2026-04',
              'start': '2026-04-21',
              'end': '2026-05-21',
              'jalali_year': 1405,
              'jalali_month': 2,
              ...statsJson(receipts: 3000000, payments: 1000000),
            },
            {
              'period': '2026-05',
              'start': '2026-05-22',
              'end': '2026-06-21',
              'jalali_year': 1405,
              'jalali_month': 3,
              ...statsJson(receipts: 2000000, payments: 1000000),
            },
          ];
    return json({
      'calendar': 'jalali',
      'group_by': yearly ? 'year' : 'month',
      'today': '2026-06-01',
      'totals': statsJson(
        receipts: 5000000,
        payments: 2000000,
        probable: 900000,
        overdue: 400000,
      ),
      'buckets': buckets,
    });
  }

  http.Response _customer() => json({
    'customer_id': 'c1',
    'documents': docs,
    'totals': statsJson(receipts: 1500000),
  });
}

({FinanceEnv env, FakeLive live}) financeEnv(
  FakeFinanceServer server, {
  FilePickFn? pick,
}) {
  final f = fakeApi(server.handle);
  final live = FakeLive(f.client);
  final env = FinanceEnv(
    api: FinanceApi(WorkspaceApi(f.client, httpClient: f.api.httpClient)),
    live: live,
    userId: 2,
    pickFile: pick,
    saveFile: (bytes, {required name, mimeType}) async {},
  );
  return (env: env, live: live);
}

Future<PickedFile?> pickPdf() async => PickedFile(
  name: 'cheque.pdf',
  bytes: Uint8List.fromList([1, 2, 3]),
  contentType: 'application/pdf',
);
