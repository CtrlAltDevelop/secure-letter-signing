import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/tasks/tasks_api.dart';

import 'task_fixtures.dart';

void main() {
  test('list sends the box, filters and paging as query parameters', () async {
    final f = tasksFixture();
    await f.env.api.list(
      box: 'followup',
      status: 'done',
      q: 'budget',
      label: 3,
      limit: 20,
      offset: 40,
    );
    final q = f.server.calls.first.url.queryParameters;
    expect(q, {
      'box': 'followup',
      'status': 'done',
      'q': 'budget',
      'label': '3',
      'limit': '20',
      'offset': '40',
    });
  });

  test('empty filters are left out of the query', () async {
    final f = tasksFixture();
    await f.env.api.list();
    final q = f.server.calls.first.url.queryParameters;
    expect(q.containsKey('status'), isFalse);
    expect(q.containsKey('q'), isFalse);
    expect(q.containsKey('label'), isFalse);
  });

  test('403, 404 and 409 become typed exceptions', () async {
    final f = tasksFixture(server: FakeTasksServer(tasks: [fullTask('t1')]));
    final api = f.env.api;
    f.server.failNext = 403;
    await expectLater(api.get('t1'), throwsA(isA<ForbiddenException>()));
    await expectLater(api.get('missing'), throwsA(isA<NotFoundException>()));
    f.server.conflictNext = true;
    await expectLater(
      api.patch('t1', {'title': 'x'}, version: 1),
      throwsA(isA<ConflictException>()),
    );
    f.server.failNext = 500;
    await expectLater(
      api.get('t1'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 500)),
    );
  });

  test('checklist reorder sends both id key spellings', () async {
    final f = tasksFixture(
      server: FakeTasksServer(
        tasks: [
          fullTask('t1', items: [checkItem(1, 'a'), checkItem(2, 'b')]),
        ],
      ),
    );
    await f.env.api.reorderChecklist('t1', [2, 1]);
    expect(f.server.lastBody('PUT', '/checklist/order'), {
      'ids': [2, 1],
      'item_ids': [2, 1],
    });
  });

  test('upload goes out as multipart with content type and name', () async {
    final f = tasksFixture();
    await f.env.api.workspace.uploadFile(
      's-t1',
      name: 'a.pdf',
      bytes: Uint8List.fromList([1, 2]),
      contentType: 'application/pdf',
    );
    final req = f.server.calls.last;
    expect(req.url.path, '/api/subjects/s-t1/files');
    expect(req.headers['Authorization'], 'Bearer tok');
    expect(req.headers['content-type'], startsWith('multipart/form-data'));
  });

  test('labels and directory parse', () async {
    final f = tasksFixture(
      server: FakeTasksServer()
        ..labels.add({'id': 1, 'name': 'A', 'color': 2, 'scope': 'org'}),
    );
    final labels = await f.env.api.workspace.labels();
    expect(labels.single.name, 'A');
    final people = await f.env.api.workspace.directory();
    expect(people.map((u) => u.displayName), ['Me', 'Bob', 'Carol']);
  });
}
