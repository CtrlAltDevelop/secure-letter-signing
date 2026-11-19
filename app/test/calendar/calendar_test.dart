import 'package:material_ui/material_ui.dart' show ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/calendar/calendar_api.dart';
import 'package:letter_signing/calendar/calendar_controller.dart';
import 'package:letter_signing/calendar/calendar_env.dart';
import 'package:letter_signing/calendar/calendar_screen.dart';
import 'package:letter_signing/calendar/colleague_tasks_screen.dart';
import 'package:letter_signing/calendar/models.dart';
import 'package:letter_signing/projects/projects_api.dart';
import 'package:letter_signing/workspace/open_target.dart';

import '../helpers.dart';
import '../letters/fakes.dart';
import '../prefs/ws_harness.dart';
import '../tasks/task_fixtures.dart' show briefTask;

final _today = DateTime(2026, 3, 10); // 19 Esfand 1404

Map<String, dynamic> _item(
  String id,
  String start, {
  String? end,
  bool done = false,
  bool allDay = false,
  String kind = 'task',
}) => {
  'kind': kind,
  'id': id,
  'subject_id': 's-$id',
  'title': 'Item $id',
  'start': start,
  'end': end ?? start,
  'all_day': allDay,
  'status': done ? 'done' : 'open',
  'project_id': null,
  'project_name': '',
  'color': 0,
  'done': done,
  'owner_ids': null,
};

({CalendarEnv env, Ws ws, List<OpenTarget> opened}) _fixture({
  bool monitor = false,
}) {
  final w = ws((req, _) {
    final path = pathOf(req);
    if (path == '/calendar') {
      return json({
        'items': [
          _item('a', '2026-03-10T09:00:00'),
          _item('b', '2026-03-10T09:00:00', done: true),
          _item('m', '2026-03-12T09:00:00', kind: 'meeting'),
        ],
        'holidays': [
          {
            'id': 1,
            'date': '2026-03-10',
            'title': 'Holiday X',
            'kind': 'official',
            'active': true,
          },
        ],
        'weekend': [5],
      });
    }
    if (path.startsWith('/tasks/of/5'))
      return json([briefTask('t9', title: 'Theirs')]);
    if (path == '/labels') return json(<Object>[]);
    if (path == '/letters/directory') {
      return json([
        {'id': 5, 'email': 'x@y.z', 'full_name': 'Colleague'},
      ]);
    }
    if (path == '/projects') return json(<Object>[]);
    return json(<Object>[]);
  });
  final opened = <OpenTarget>[];
  final env = CalendarEnv(
    api: CalendarApi(w.api),
    tasks: w.tasks,
    projects: ProjectsApi(w.api),
    open: (c, t) async => opened.add(t),
    canMonitor: monitor,
  );
  return (env: env, ws: w, opened: opened);
}

void main() {
  test('item spans days; all-day end is exclusive', () {
    final i = CalendarItem.tryParse(
      _item(
        'p',
        '2026-03-10T00:00:00',
        end: '2026-03-12T00:00:00',
        allDay: true,
      ),
    )!;
    expect(i.days.length, 2);
  });

  test(
    'controller groups by day, marks holidays, filters done on device',
    () async {
      final f = _fixture();
      final c = CalendarController(f.env, today: _today);
      await c.load();
      expect(c.byDay[dayKey(_today)]!.length, 2);
      expect(c.selectedHolidays.single.title, 'Holiday X');
      await c.setFilter(const CalendarFilter(status: CalendarStatus.done));
      expect(c.byDay[dayKey(_today)]!.single.id, 'b');
      c.dispose();
    },
  );

  test('server filters become query parameters', () async {
    final f = _fixture();
    final c = CalendarController(f.env, today: _today);
    await c.setFilter(
      const CalendarFilter(
        projectId: 'p1',
        labelId: 3,
        customerId: 'c1',
        ownerId: 5,
      ),
    );
    final q = f.ws.where('GET', '/calendar').last.url.queryParameters;
    expect(
      [q['project'], q['label'], q['customer'], q['owner']],
      ['p1', '3', 'c1', '5'],
    );
    c.dispose();
  });

  testWidgets('month view shows counts, holiday and opens an item', (t) async {
    await useTallSurface(t);
    final f = _fixture();
    await t.pumpWidget(
      faMaterial(
        home: CalendarScreen(env: f.env, today: _today),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('cal-count-2026-03-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('cal-holiday-Holiday X')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('cal-item-task-a')));
    expect(f.opened.single.module, 'tasks');
    expect(find.byKey(const ValueKey('cal-team')), findsNothing);
  });

  testWidgets('team calendar toggle needs monitor.view and sends team=true', (
    t,
  ) async {
    await useTallSurface(t);
    final f = _fixture(monitor: true);
    await t.pumpWidget(
      faMaterial(
        home: CalendarScreen(env: f.env, today: _today),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('cal-team')));
    await t.pumpAndSettle();
    expect(f.ws.where('GET', 'team=true'), isNotEmpty);
  });

  testWidgets('week view loads seven days', (t) async {
    await useTallSurface(t);
    final f = _fixture();
    await t.pumpWidget(
      faMaterial(
        home: CalendarScreen(env: f.env, today: _today),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('هفته'));
    await t.pumpAndSettle();
    final q = f.ws.where('GET', '/calendar').last.url.queryParameters;
    final span = DateTime.parse(q['to']!)
        .difference(DateTime.parse(q['from']!));
    expect(span.inDays, anyOf(6, 7)); // 7 days, minus an hour on a DST change
  });

  testWidgets('colleague inbox lists the tasks of the chosen person', (
    t,
  ) async {
    await useTallSurface(t);
    final f = _fixture(monitor: true);
    await t.pumpWidget(faMaterial(home: ColleagueTasksScreen(env: f.env)));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('colleague-picker')));
    await t.pumpAndSettle();
    await t.tap(find.text('Colleague').last);
    await t.pumpAndSettle();
    expect(f.ws.where('GET', '/tasks/of/5'), isNotEmpty);
    expect(find.text('Theirs'), findsOneWidget);
  });
}
