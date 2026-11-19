import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/monitor/group_access_sheet.dart';
import 'package:letter_signing/monitor/monitor_api.dart';
import 'package:letter_signing/monitor/monitor_screen.dart';
import 'package:letter_signing/monitor/my_numbers_card.dart';
import 'package:letter_signing/monitor/tasks_print.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import '../letters/fakes.dart';
import 'monitor_fixtures.dart';

const _sizes = [Size(375, 812), Size(844, 390)];

Future<FakeMonitorServer> _open(
  WidgetTester t,
  Size size, {
  Set<String> hide = const {},
}) async {
  final s = FakeMonitorServer(hide: hide);
  await useTallSurface(t, size);
  await t.pumpWidget(faMaterial(home: MonitorScreen(env: monitorEnv(s))));
  await t.pumpAndSettle();
  return s;
}

Future<void> _tab(WidgetTester t, String label) async {
  await t.ensureVisible(find.text(label).first);
  await t.pumpAndSettle();
  await t.tap(find.text(label).first);
  await t.pumpAndSettle();
}

void main() {
  test('MonitorPeriod builds preset and custom queries', () {
    expect(const MonitorPeriod().query(), {
      'period': 'month',
      'calendar': 'jalali',
      'bucket': 'day',
    });
    final c = const MonitorPeriod().copyWith(
      from: DateTime(2026, 1, 2),
      to: DateTime(2026, 1, 9),
    );
    expect(c.query()['from'], '2026-01-02');
    expect(c.query().containsKey('period'), isFalse);
    expect(c.copyWith(preset: 'week').custom, isFalse);
  });

  testWidgets('My numbers card shows the server numbers', (t) async {
    final s = FakeMonitorServer();
    await useTallSurface(t);
    await t.pumpWidget(
      faMaterial(
        home: Scaffold(
          body: MyNumbersCard(env: monitorEnv(s, canMonitor: false)),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('۵'), findsOneWidget); // open
    expect(find.text('۹'), findsOneWidget); // unread chat
    expect(find.text('اعداد من'), findsOneWidget);
  });

  for (final size in _sizes) {
    testWidgets('tabs: finance hidden on 404, sales shown at $size', (t) async {
      await _open(t, size, hide: {'/monitor/finance'});
      expect(find.text('نمای کلی'), findsOneWidget);
      expect(find.text('مالی'), findsNothing);
      expect(find.text('فروش'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('period chip reaches the server', (t) async {
    final s = await _open(t, _sizes.first);
    await t.tap(find.byKey(const ValueKey('period-week')));
    await t.pumpAndSettle();
    expect(
      s.where('GET', '/monitor/overview').last.url.queryParameters['period'],
      'week',
    );
    await t.tap(find.byKey(const ValueKey('bucket-month')));
    await t.pumpAndSettle();
    expect(
      s.where('GET', '/monitor/overview').last.url.queryParameters['bucket'],
      'month',
    );
  });

  testWidgets('projects sort reaches the server', (t) async {
    final s = await _open(t, _sizes.first);
    await _tab(t, 'پروژه‌ها');
    expect(find.text('Group One'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('projects-sort')));
    await t.pumpAndSettle();
    await t.tap(find.text('بیشترین عقب‌افتادگی').last);
    await t.pumpAndSettle();
    expect(
      s.where('GET', '/monitor/projects').last.url.queryParameters['sort'],
      'most_overdue',
    );
  });

  testWidgets('tasks tab lists overdue and prints with printable=true', (
    t,
  ) async {
    final s = await _open(t, const Size(800, 2000));
    await _tab(t, 'کارها');
    expect(find.text('Late task'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('tasks-print')));
    await t.pumpAndSettle();
    expect(
      s.where('GET', '/monitor/tasks').last.url.queryParameters['printable'],
      'true',
    );
    expect(find.byKey(const ValueKey('tasks-print-go')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('members row opens the colleague inbox', (t) async {
    final s = await _open(t, _sizes.first);
    await _tab(t, 'اعضا');
    await t.tap(find.byKey(const ValueKey('member-2')));
    await t.pumpAndSettle();
    expect(s.where('GET', '/tasks/of/2'), isNotEmpty);
    expect(find.text('Their task'), findsOneWidget);
  });

  testWidgets('online tab loads login history of one user', (t) async {
    final s = await _open(t, _sizes.first);
    await _tab(t, 'آنلاین');
    await t.tap(find.byKey(const ValueKey('history-2')));
    await t.pumpAndSettle();
    expect(
      s.where('GET', '/monitor/online').last.url.queryParameters['history_of'],
      '2',
    );
    expect(find.textContaining('Pixel'), findsOneWidget);
  });

  testWidgets('customers and meetings tabs render', (t) async {
    await _open(t, _sizes.first);
    await _tab(t, 'جلسات');
    expect(find.text('Board'), findsOneWidget);
    await _tab(t, 'مشتریان');
    expect(find.text('Acme'), findsOneWidget);
  });

  testWidgets('group access editor sends add and remove', (t) async {
    final s = FakeMonitorServer();
    final env = monitorEnv(s);
    await useTallSurface(t, _sizes.first);
    await t.pumpWidget(
      faMaterial(
        home: Scaffold(
          body: GroupAccessSheet(
            api: env.api,
            groupId: 4,
            directory: env.directory!,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('access-user')));
    await t.pumpAndSettle();
    await t.tap(find.text('Sara').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('access-add')));
    await t.pumpAndSettle();
    expect(s.bodies.last, {
      'add': [
        {'user_id': 2, 'role': 'member'},
      ],
      'remove': <Object>[],
    });
    await t.tap(find.byKey(const ValueKey('access-remove')));
    await t.pumpAndSettle();
    expect(s.bodies.last, {
      'add': <Object>[],
      'remove': [2],
    });
    expect(s.where('PUT', '/project-groups/4/access'), hasLength(2));
  });

  testWidgets('overdue print blocks include heading, header and rows', (
    t,
  ) async {
    late AppLocalizations l;
    await t.pumpWidget(
      faMaterial(
        home: Builder(
          builder: (c) {
            l = AppLocalizations.of(c);
            return const SizedBox();
          },
        ),
      ),
    );
    final blocks = overdueBlocks(l, [
      {'title': 'x', 'days_late': 1, 'owners': <Object>[]},
    ]);
    expect(blocks, hasLength(3));
  });
}
