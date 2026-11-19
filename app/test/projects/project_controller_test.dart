import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/projects/project_controller.dart';
import 'package:letter_signing/projects/project_views_controller.dart';
import 'package:letter_signing/workspace/subject_controller.dart';

import '../tasks/task_fixtures.dart';
import 'project_fixtures.dart';

ProjectsFixture _fixture() {
  final f = projectsFixture();
  f.server.board = [
    boardTask('a', 1, 100, title: 'A'),
    boardTask('b', 1, 200, title: 'B'),
    boardTask('c', 2, 100, title: 'C'),
  ];
  return f;
}

List<String> _ids(ProjectController c, int col) => [
  for (final t in c.board.firstWhere((x) => x.id == col).tasks) t.id,
];

void main() {
  test('load reads the project and the board', () async {
    final f = _fixture();
    final c = ProjectController(env: f.env, projectId: 'p1');
    addTearDown(c.dispose);
    await c.load();
    expect(c.project!.name, 'Alpha');
    expect(c.board.map((x) => x.title), ['To do', 'Doing', 'Done']);
    expect(_ids(c, 1), ['a', 'b']);
  });

  test('moveTask updates the board at once and posts before_id', () async {
    final f = _fixture();
    final c = ProjectController(env: f.env, projectId: 'p1');
    addTearDown(c.dispose);
    await c.load();
    final task = c.board[0].tasks.first;
    final pending = c.moveTask(task, 2, beforeId: 'c');
    expect(_ids(c, 2), ['a', 'c']);
    expect(_ids(c, 1), ['b']);
    expect(await pending, ActionOutcome.ok);
    final body = f.server.lastBody('POST', '/tasks/a/move')! as Map;
    expect(body, {'project_id': 'p1', 'column_id': 2, 'before_id': 'c'});
    expect(_ids(c, 2), ['a', 'c']);
  });

  test('a failed move rolls the board back', () async {
    final f = _fixture();
    final c = ProjectController(env: f.env, projectId: 'p1');
    addTearDown(c.dispose);
    await c.load();
    final seen = <List<String>>[];
    c.addListener(() => seen.add(_ids(c, 2)));
    f.server.failMove = 409;
    final outcome = await c.moveTask(c.board[0].tasks.first, 2);
    expect(outcome, ActionOutcome.conflict);
    expect(seen.first, ['c', 'a']);
    expect(_ids(c, 1), ['a', 'b']);
    expect(_ids(c, 2), ['c']);
  });

  test('shiftColumn reorders through the API and addColumn appends', () async {
    final f = _fixture();
    final c = ProjectController(env: f.env, projectId: 'p1');
    addTearDown(c.dispose);
    await c.load();
    await c.shiftColumn(2, -1);
    expect(c.board.map((x) => x.id), [2, 1, 3]);
    expect(f.server.lastBody('PUT', '/columns/order'), {
      'ids': [2, 1, 3],
    });
    await c.addColumn('Review');
    expect(c.board.last.title, 'Review');
    expect(await c.shiftColumn(2, -1), ActionOutcome.failed);
  });

  test('addTask posts project and column ids', () async {
    final f = _fixture();
    final c = ProjectController(env: f.env, projectId: 'p1');
    addTearDown(c.dispose);
    await c.load();
    await c.addTask(2, 'New one');
    final body = f.server.tasks.lastBody('POST', '/tasks')! as Map;
    expect(body['project_id'], 'p1');
    expect(body['column_id'], 2);
    expect(body['owner_ids'], [2]);
  });

  test('sorting is per column and client side', () async {
    final f = _fixture();
    final c = ProjectController(env: f.env, projectId: 'p1');
    addTearDown(c.dispose);
    await c.load();
    c.setSort(1, ColumnSort.createdDesc);
    expect([for (final t in c.shown(c.board[0])) t.id], ['b', 'a']);
    expect([for (final t in c.shown(c.board[1])) t.id], ['c']);
  });

  test('calendar controller asks for the Jalali month range', () async {
    final f = _fixture();
    f.server.calendar = [
      briefTask('t1', dueAt: '2026-03-25T08:00:00Z'),
      briefTask('t2', dueAt: '2026-03-25T09:00:00Z'),
    ];
    final cal = ProjectCalendarController(
      f.env,
      'p1',
      today: DateTime(2026, 3, 25),
    );
    addTearDown(cal.dispose);
    await cal.load();
    expect(cal.month.title, 'فروردین ۱۴۰۵');
    expect(cal.byDay.values.expand((e) => e).length, 2);
    final q = f.server.calls.last.url.queryParameters;
    expect(q['view'], 'calendar');
    expect(DateTime.parse(q['from']!).toLocal(), DateTime(2026, 3, 21));
    await cal.shift(-1);
    expect(cal.month.title, 'اسفند ۱۴۰۴');
  });

  test('files controller hides itself on 404', () async {
    final f = _fixture()..server.optionalEndpoints = false;
    final files = ProjectFilesController(f.env, 'p1');
    addTearDown(files.dispose);
    await files.load();
    expect(files.supported, isFalse);
  });
}
