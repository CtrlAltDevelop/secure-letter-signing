import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/l10n/app_localizations_fa.dart';
import 'package:letter_signing/tasks/tasks_screen.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import 'task_fixtures.dart';

final _l = AppLocalizationsFa();

Future<void> _pump(
  WidgetTester t,
  TasksFixture f, {
  Size size = const Size(400, 800),
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.reset);
  await t.pumpWidget(faApp(TasksScreen(env: f.env)));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('inbox lists tasks with unseen dot and Jalali due date', (
    t,
  ) async {
    final f = tasksFixture(
      server: FakeTasksServer(
        tasks: [
          briefTask(
            'a',
            title: 'Prepare budget',
            unseen: true,
            dueAt: '2099-03-01T10:00:00Z',
          ),
          briefTask('b', title: 'Review contract', priority: 'urgent'),
        ],
      ),
    );
    await _pump(t, f);
    expect(find.text('Prepare budget'), findsOneWidget);
    expect(find.text('Review contract'), findsOneWidget);
    expect(find.byKey(const ValueKey('unseen-dot')), findsOneWidget);
    expect(find.text(_l.taskPriorityUrgent), findsOneWidget);
    // 2099-03-01 is 1477/12/10 in the Persian calendar (digits are Persian).
    final due = t.widget<Text>(find.byKey(const ValueKey('due-text')));
    expect(due.data, contains('۱۴۷۷/'));
    expect(
      f.server.where('GET', '/tasks').first.url.queryParameters['box'],
      'inbox',
    );
  });

  testWidgets('overdue tasks show their due date in the error colour', (
    t,
  ) async {
    final f = tasksFixture(
      server: FakeTasksServer(
        tasks: [
          briefTask('late', title: 'Late', dueAt: '2020-01-01T10:00:00Z'),
          briefTask('ok', title: 'Fine', dueAt: '2099-01-01T10:00:00Z'),
          briefTask(
            'done',
            title: 'Done',
            status: 'done',
            dueAt: '2020-01-01T10:00:00Z',
          ),
        ],
      ),
    );
    await _pump(t, f);
    final colors = [
      for (final w in t.widgetList<Text>(
        find.byKey(const ValueKey('due-text')),
      ))
        w.style?.color,
    ];
    expect(colors.where((c) => c == Tokens.error).length, 1);
    expect(colors.length, 3);
  });

  testWidgets('tabs load their own box lazily', (t) async {
    final f = tasksFixture(server: FakeTasksServer(tasks: [briefTask('a')]));
    await _pump(t, f);
    expect(f.server.where('GET', '/tasks').length, 1);
    await t.tap(find.text(_l.tasksTabFollowup));
    await t.pumpAndSettle();
    final boxes = [
      for (final r in f.server.where('GET', '/tasks'))
        r.url.queryParameters['box'],
    ];
    expect(boxes, ['inbox', 'followup']);
    await t.tap(find.text(_l.tasksTabAll));
    await t.pumpAndSettle();
    expect(f.server.where('GET', '/tasks').length, 3);
  });

  testWidgets('status filter chip reloads with that status', (t) async {
    final f = tasksFixture(
      server: FakeTasksServer(
        tasks: [
          briefTask('a', title: 'Open one'),
          briefTask('b', title: 'Finished one', status: 'done'),
        ],
      ),
    );
    await _pump(t, f, size: const Size(900, 800));
    expect(find.text('Open one'), findsOneWidget);
    await t.tap(find.widgetWithText(ChoiceChip, _l.taskStatusDone));
    await t.pumpAndSettle();
    expect(find.text('Open one'), findsNothing);
    expect(find.text('Finished one'), findsOneWidget);
    expect(
      f.server.where('GET', '/tasks').last.url.queryParameters['status'],
      'done',
    );
  });

  testWidgets('search submits the query', (t) async {
    final f = tasksFixture(
      server: FakeTasksServer(
        tasks: [
          briefTask('a', title: 'Alpha'),
          briefTask('b', title: 'Beta'),
        ],
      ),
    );
    await _pump(t, f);
    await t.enterText(find.byType(TextField), 'bet');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pumpAndSettle();
    expect(find.text('Alpha'), findsNothing);
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('label chips filter by label', (t) async {
    final server =
        FakeTasksServer(
            tasks: [
              briefTask('a', title: 'Alpha', labelIds: [1]),
            ],
          )
          ..labels.add({
            'id': 1,
            'name': 'Urgent stuff',
            'color': 2,
            'scope': 'org',
            'active': true,
          });
    final f = tasksFixture(server: server);
    await _pump(t, f);
    await t.tap(find.widgetWithText(FilterChip, 'Urgent stuff'));
    await t.pumpAndSettle();
    expect(
      server.where('GET', '/tasks').last.url.queryParameters['label'],
      '1',
    );
  });

  testWidgets('empty inbox shows the empty state with a create action', (
    t,
  ) async {
    final f = tasksFixture();
    await _pump(t, f);
    expect(find.text(_l.tasksEmptyInboxTitle), findsOneWidget);
    expect(find.widgetWithText(FilledButton, _l.taskNew), findsOneWidget);
  });

  testWidgets('an empty filtered result explains the filter', (t) async {
    final f = tasksFixture(server: FakeTasksServer(tasks: [briefTask('a')]));
    await _pump(t, f, size: const Size(900, 800));
    await t.tap(find.widgetWithText(ChoiceChip, _l.taskStatusDone));
    await t.pumpAndSettle();
    expect(find.text(_l.tasksEmptyFilteredTitle), findsOneWidget);
  });

  testWidgets('a load failure offers retry', (t) async {
    final server = FakeTasksServer(tasks: [briefTask('a', title: 'Alpha')])
      ..failNext = 500;
    final f = tasksFixture(server: server);
    await _pump(t, f);
    expect(find.text(_l.tasksLoadFailed), findsOneWidget);
    await t.tap(find.text(_l.commonRetry));
    await t.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets('no create button without the task.create permission', (t) async {
    final f = tasksFixture(canCreate: false);
    await _pump(t, f);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.widgetWithText(FilledButton, _l.taskNew), findsNothing);
  });

  testWidgets('a live task event reloads the visible list', (t) async {
    final f = tasksFixture(
      server: FakeTasksServer(tasks: [briefTask('a', title: 'Alpha')]),
    );
    await _pump(t, f);
    f.server.tasks.add(briefTask('b', title: 'Brand new'));
    f.live.push({
      'type': 'ws',
      'stream': 'w',
      'module': 'tasks',
      'kind': 'task.created',
    });
    await t.pumpAndSettle();
    expect(find.text('Brand new'), findsOneWidget);
  });

  for (final size in const [Size(375, 812), Size(844, 390)]) {
    testWidgets(
      'list renders without overflow at ${size.width}x${size.height}',
      (t) async {
        final f = tasksFixture(
          server: FakeTasksServer(
            tasks: [
              for (var i = 0; i < 6; i++)
                briefTask(
                  'x$i',
                  title:
                      'A fairly long task title number $i that wraps over lines',
                  priority: 'high',
                  status: i.isEven ? 'open' : 'awaiting_approval',
                  dueAt: '2020-01-01T10:00:00Z',
                  unseen: true,
                  checklist: {'done': 1, 'total': 3},
                  progress: 33,
                ),
            ],
          ),
        );
        await _pump(t, f, size: size);
        expect(t.takeException(), isNull);
        await t.drag(find.byType(Scrollable).last, const Offset(0, -300));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      },
    );
  }
}
