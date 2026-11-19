import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/tasks/tasks_controller.dart';

import 'task_fixtures.dart';

FakeTasksServer _serverWith(int n, {String status = 'open'}) => FakeTasksServer(
  tasks: [
    for (var i = 0; i < n; i++)
      fullTask('t$i', title: 'Task $i', status: status),
  ],
);

void main() {
  test('load fetches the first page and reports more', () async {
    final f = tasksFixture(server: _serverWith(5));
    final c = TasksListController(
      api: f.env.api,
      live: f.live,
      box: TaskBox.inbox,
      pageSize: 2,
    );
    addTearDown(c.dispose);
    await c.load();
    expect(c.items.map((t) => t.id), ['t0', 't1']);
    expect(c.hasMore, isTrue);
    expect(c.loaded, isTrue);
    expect(c.loading, isFalse);
    final req = f.server.where('GET', '/tasks').first;
    expect(req.url.queryParameters['box'], 'inbox');
    expect(req.url.queryParameters['limit'], '2');
  });

  test('loadMore appends pages until the end', () async {
    final f = tasksFixture(server: _serverWith(5));
    final c = TasksListController(
      api: f.env.api,
      live: f.live,
      box: TaskBox.all,
      pageSize: 2,
    );
    addTearDown(c.dispose);
    await c.load();
    await c.loadMore();
    expect(c.items.length, 4);
    await c.loadMore();
    expect(c.items.length, 5);
    expect(c.hasMore, isFalse);
    final before = f.server.calls.length;
    await c.loadMore();
    expect(f.server.calls.length, before);
  });

  test('status, query and label filters reload from the first page', () async {
    final server = FakeTasksServer(
      tasks: [
        fullTask('a', title: 'Alpha'),
        fullTask('b', title: 'Beta', status: 'done'),
      ],
    );
    final f = tasksFixture(server: server);
    final c = TasksListController(
      api: f.env.api,
      live: f.live,
      box: TaskBox.all,
    );
    addTearDown(c.dispose);
    await c.load();
    expect(c.items.length, 2);
    expect(c.filtered, isFalse);

    await c.setStatus('done');
    expect(c.items.map((t) => t.id), ['b']);
    expect(c.filtered, isTrue);

    await c.setStatus('');
    await c.setQuery('alp');
    expect(c.items.map((t) => t.id), ['a']);

    await c.setLabel(7);
    final last = server.where('GET', '/tasks').last;
    expect(last.url.queryParameters['label'], '7');
    expect(last.url.queryParameters['q'], 'alp');
    expect(last.url.queryParameters['offset'], '0');

    await c.setCustomer('cust-1', name: 'Acme');
    expect(
      server.where('GET', '/tasks').last.url.queryParameters['customer'],
      'cust-1',
    );
    expect(c.customerName, 'Acme');
    await c.setCustomer(null);
    expect(c.customerId, isNull);
  });

  test('a workspace task event refreshes the shown rows', () async {
    final server = _serverWith(1);
    final f = tasksFixture(server: server);
    final c = TasksListController(
      api: f.env.api,
      live: f.live,
      box: TaskBox.inbox,
    );
    addTearDown(c.dispose);
    await c.load();
    expect(c.items.length, 1);

    server.tasks.add(fullTask('new', title: 'New'));
    f.live.push({
      'type': 'ws',
      'stream': 'w',
      'module': 'tasks',
      'kind': 'task.created',
    });
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.items.map((t) => t.id), ['t0', 'new']);
  });

  test('letter events and other modules are ignored', () async {
    final f = tasksFixture(server: _serverWith(1));
    final c = TasksListController(
      api: f.env.api,
      live: f.live,
      box: TaskBox.inbox,
    );
    addTearDown(c.dispose);
    await c.load();
    final before = f.server.calls.length;
    f.live.push({'type': 'letter', 'kind': 'sent'});
    f.live.push({
      'type': 'ws',
      'stream': 'w',
      'module': 'projects',
      'kind': 'x',
    });
    await Future<void>.delayed(Duration.zero);
    expect(f.server.calls.length, before);
  });

  test('a failed load keeps the error and recovers on retry', () async {
    final f = tasksFixture(server: _serverWith(1));
    final c = TasksListController(
      api: f.env.api,
      live: f.live,
      box: TaskBox.inbox,
    );
    addTearDown(c.dispose);
    f.server.failNext = 500;
    await c.load();
    expect(c.error, isNotNull);
    expect(c.items, isEmpty);
    expect(c.loaded, isTrue);
    await c.load();
    expect(c.error, isNull);
    expect(c.items.length, 1);
  });

  test('a failed live refresh keeps the rows already shown', () async {
    final f = tasksFixture(server: _serverWith(2));
    final c = TasksListController(
      api: f.env.api,
      live: f.live,
      box: TaskBox.inbox,
    );
    addTearDown(c.dispose);
    await c.load();
    f.server.failNext = 500;
    await c.refresh();
    expect(c.items.length, 2);
  });
}
