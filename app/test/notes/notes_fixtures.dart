import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:letter_signing/notes/notes_api.dart';
import 'package:letter_signing/notes/notes_env.dart';
import 'package:letter_signing/workspace/file_pick.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

import '../letters/fakes.dart';

Map<String, dynamic> noteJson(
  String id, {
  String title = 'Note',
  String body = '',
  int color = 0,
  bool pinned = false,
  bool archived = false,
  List<Map<String, dynamic>> items = const [],
  List<int> labelIds = const [],
  int images = 0,
}) => {
  'id': id,
  'subject_id': 'ns-$id',
  'title': title,
  'body': {'text': body},
  'color': color,
  'pinned': pinned,
  'archived': archived,
  'checklist_items': items,
  'label_ids': labelIds,
  'image_count': images,
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-01T00:00:00Z',
};

Map<String, dynamic> itemJson(int id, String text, {bool done = false}) => {
  'id': id,
  'text': text,
  'done': done,
};

/// A scripted in-memory notes server; every request is recorded.
class FakeNotesServer {
  final List<Map<String, dynamic>> notes = [];
  final List<Map<String, dynamic>> files = [];
  final List<Map<String, dynamic>> labels = [
    {'id': 1, 'name': 'Work', 'color': 1, 'scope': 'org', 'active': true},
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
      notes.firstWhere((n) => n['id'] == id);

  http.Response handle(http.Request req, Object? body) {
    calls.add(req);
    bodies.add(body);
    final path = req.url.path.replaceFirst('/api', '');
    final m = req.method;
    if (path == '/labels') return json(labels);
    if (path.startsWith('/subjects/')) return _subject(path, m);
    if (path == '/notes' && m == 'GET') return _list(req.url);
    if (path == '/notes' && m == 'POST') return _create(body as Map);
    if (path.startsWith('/files/')) {
      return http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200);
    }
    return _note(path.split('/'), m, body is Map ? body : const {});
  }

  http.Response _subject(String path, String m) {
    if (path.endsWith('/files') && m == 'POST') {
      final f = {
        'id': 'f${_next++}',
        'name': 'p.png',
        'content_type': 'image/png',
        'size': 3,
      };
      files.add(f);
      return json(f, 201);
    }
    if (path.endsWith('/labels')) return json({'label_ids': <int>[]});
    if (path.endsWith('/files')) return json(files);
    return json(<Object>[]);
  }

  http.Response _list(Uri url) {
    final q = (url.queryParameters['q'] ?? '').toLowerCase();
    final archived = url.queryParameters['archived'] == 'true';
    final rows = [
      for (final n in notes)
        if ((n['archived'] == true) == archived &&
            (q.isEmpty || '${n['title']}'.toLowerCase().contains(q)))
          n,
    ];
    rows.sort(
      (a, b) => (b['pinned'] == true ? 1 : 0) - (a['pinned'] == true ? 1 : 0),
    );
    return json(rows);
  }

  http.Response _create(Map body) {
    final items = [
      for (final (i, t) in (body['checklist'] as List).indexed)
        itemJson(i + 1, '$t'),
    ];
    final n = noteJson(
      'n${_next++}',
      title: body['title'] as String,
      body: (body['body'] as Map)['text'] as String,
      color: body['color'] as int,
      pinned: body['pinned'] as bool,
      items: items,
    );
    notes.add(n);
    return json(n, 201);
  }

  http.Response _note(List<String> seg, String m, Map body) {
    final n = _find(seg[2]);
    final tail = seg.length > 3 ? seg.sublist(3).join('/') : '';
    final items = (n['checklist_items'] as List).cast<Map<String, dynamic>>();
    if (tail == 'pin') n['pinned'] = body['pinned'];
    if (tail == 'archive') n['archived'] = body['archived'];
    if (tail == '' && m == 'PATCH') {
      for (final e in body.entries) {
        n[e.key as String] = e.value;
      }
    }
    if (tail == 'checklist') {
      items.add(itemJson(50 + items.length, body['text'] as String));
    }
    if (tail.startsWith('checklist/order')) {
      final ids = (body['item_ids'] as List).cast<int>();
      items.sort(
        (a, b) => ids.indexOf(a['id'] as int) - ids.indexOf(b['id'] as int),
      );
    } else if (tail.startsWith('checklist/')) {
      final item = items.firstWhere(
        (i) => i['id'] == int.parse(tail.split('/')[1]),
      );
      if (body['done'] != null) item['done'] = body['done'];
      if (body['active'] == false) items.remove(item);
    }
    return json(n, tail == 'checklist' ? 201 : 200);
  }
}

({NotesEnv env, FakeLive live}) notesEnv(
  FakeNotesServer server, {
  FilePickFn? pick,
}) {
  final f = fakeApi(server.handle);
  final live = FakeLive(f.client);
  final env = NotesEnv(
    api: NotesApi(WorkspaceApi(f.client, httpClient: f.api.httpClient)),
    live: live,
    userId: 2,
    pickFile: pick,
  );
  return (env: env, live: live);
}

/// A tiny picked image.
Future<PickedFile?> pickImage() async => PickedFile(
  name: 'p.png',
  bytes: Uint8List.fromList([1, 2, 3]),
  contentType: 'image/png',
);

/// A picked PDF (not an image).
Future<PickedFile?> pickPdf() async => PickedFile(
  name: 'a.pdf',
  bytes: Uint8List.fromList([1]),
  contentType: 'application/pdf',
);
