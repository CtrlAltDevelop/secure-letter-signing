import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/l10n/app_localizations_fa.dart';
import 'package:letter_signing/projects/board_view.dart';
import 'package:letter_signing/projects/project_controller.dart';
import 'package:letter_signing/workspace/widgets/progress_ring.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import 'project_fixtures.dart';

final _l = AppLocalizationsFa();

Future<({ProjectController c, ProjectsFixture f, List<String> opened})> _open(
  WidgetTester t, {
  Size size = const Size(844, 390),
  bool manager = true,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.reset);
  final f = projectsFixture();
  f.server.projects[0]['my_role'] = manager ? 'manager' : 'viewer';
  f.server.board = [
    boardTask('a', 1, 100, title: 'Task A'),
    boardTask('b', 1, 200, title: 'Task B'),
    boardTask('c', 2, 100, title: 'Task C', status: 'done'),
  ];
  final c = ProjectController(env: f.env, projectId: 'p1');
  addTearDown(c.dispose);
  final opened = <String>[];
  await t.pumpWidget(faApp(BoardView(controller: c, onOpenTask: opened.add)));
  await c.load();
  await t.pumpAndSettle();
  return (c: c, f: f, opened: opened);
}

Future<void> _drag(WidgetTester t, Finder from, Offset to) async {
  final g = await t.startGesture(t.getCenter(from));
  await t.pump(const Duration(milliseconds: 600));
  await g.moveTo(to);
  await t.pump();
  await g.up();
  await t.pumpAndSettle();
}

Finder _drag_(String id) => find.byKey(ValueKey('drag-$id'));

void main() {
  testWidgets('long press and drag moves a card to another column', (t) async {
    final h = await _open(t);
    await _drag(
      t,
      _drag_('a'),
      t.getCenter(find.byKey(const ValueKey('drag-c'))),
    );
    final body = h.f.server.lastBody('POST', '/tasks/a/move')! as Map;
    expect(body['column_id'], 2);
    expect(body['before_id'], 'c');
    expect([for (final x in h.c.board[1].tasks) x.id], ['a', 'c']);
    expect([for (final x in h.c.board[0].tasks) x.id], ['b']);
  });

  testWidgets('dropping on the empty part of a column appends', (t) async {
    final h = await _open(t);
    final column = find.byKey(const ValueKey('drop-end-2'));
    final box = t.getRect(column);
    await _drag(t, _drag_('a'), Offset(box.center.dx, box.bottom - 6));
    final body = h.f.server.lastBody('POST', '/tasks/a/move')! as Map;
    expect(body['column_id'], 2);
    expect(body['before_id'], isNull);
  });

  testWidgets('reordering inside a column works at phone size', (t) async {
    final h = await _open(t, size: const Size(375, 812));
    await _drag(t, _drag_('b'), t.getCenter(_drag_('a')));
    final body = h.f.server.lastBody('POST', '/tasks/b/move')! as Map;
    expect(body['column_id'], 1);
    expect(body['before_id'], 'a');
    expect([for (final x in h.c.board[0].tasks) x.id], ['b', 'a']);
    expect(t.takeException(), isNull);
  });

  testWidgets('a failed move restores the card and shows a message', (t) async {
    final h = await _open(t);
    h.f.server.failMove = 409;
    await _drag(t, _drag_('a'), t.getCenter(_drag_('c')));
    expect([for (final x in h.c.board[0].tasks) x.id], ['a', 'b']);
    expect(find.text(_l.projectConflict), findsOneWidget);
  });

  testWidgets('viewers cannot drag', (t) async {
    final h = await _open(t, manager: false);
    expect(
      find.byWidgetPredicate((w) => w is LongPressDraggable),
      findsNothing,
    );
    expect(h.f.server.where('POST', '/move'), isEmpty);
  });

  testWidgets('shows per-column percentage and a compact toggle', (t) async {
    await _open(t);
    expect(find.text(_l.percentValue('۵۰')), findsNothing);
    expect(find.text(_l.percentValue('۱۰۰')), findsOneWidget);
    expect(find.text(_l.percentValue('۰')), findsWidgets);
    expect(find.byType(ProgressRing), findsNWidgets(3));
    await t.tap(find.byKey(const ValueKey('compact-toggle')));
    await t.pumpAndSettle();
    expect(find.byType(ProgressRing), findsNothing);
    expect(find.text('Task A'), findsOneWidget);
  });

  testWidgets('managers can add a task inline, rename and hide columns', (
    t,
  ) async {
    final h = await _open(t, size: const Size(844, 900));
    await t.tap(find.byKey(const ValueKey('add-task-1')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('add-task-field-1')), 'Fresh');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    final body = h.f.server.tasks.lastBody('POST', '/tasks')! as Map;
    expect(body['title'], 'Fresh');
    expect(body['column_id'], 1);

    await t.tap(find.byKey(const ValueKey('col-menu-2')));
    await t.pumpAndSettle();
    await t.tap(find.text(_l.columnHide));
    await t.pumpAndSettle();
    expect(h.c.board.map((x) => x.id), [1, 3]);
  });

  testWidgets('sort menu reorders a column on the client', (t) async {
    final h = await _open(t, size: const Size(844, 900));
    await t.tap(find.byKey(const ValueKey('col-sort-1')));
    await t.pumpAndSettle();
    await t.tap(find.text(_l.sortCreatedDesc));
    await t.pumpAndSettle();
    expect(h.c.sortOf(1), ColumnSort.createdDesc);
    final ya = t.getTopLeft(find.text('Task A')).dy;
    final yb = t.getTopLeft(find.text('Task B')).dy;
    expect(yb, lessThan(ya));
  });

  testWidgets('tapping a card opens it', (t) async {
    final h = await _open(t);
    await t.tap(find.text('Task C'));
    expect(h.opened, ['c']);
  });
}
