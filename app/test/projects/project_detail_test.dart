import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/l10n/app_localizations_fa.dart';
import 'package:letter_signing/projects/project_calendar_view.dart';
import 'package:letter_signing/projects/project_detail_screen.dart';
import 'package:letter_signing/projects/project_views_controller.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import '../tasks/task_fixtures.dart';
import 'project_fixtures.dart';

final _l = AppLocalizationsFa();

Future<ProjectsFixture> _open(
  WidgetTester t, {
  Size size = const Size(375, 812),
  void Function(FakeProjectsServer s)? seed,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.reset);
  final f = projectsFixture();
  f.server.board = [boardTask('a', 1, 100, title: 'Task A')];
  f.server.tasks.tasks.add(briefTask('a', title: 'Task A'));
  seed?.call(f.server);
  await t.pumpWidget(faApp(ProjectDetailScreen(env: f.env, projectId: 'p1')));
  await t.pumpAndSettle();
  return f;
}

Future<void> _tab(WidgetTester t, String label) async {
  await t.ensureVisible(find.text(label));
  await t.tap(find.text(label));
  await t.pumpAndSettle();
}

void main() {
  for (final size in [const Size(375, 812), const Size(844, 390)]) {
    testWidgets('board, list and settings tabs fit at $size', (t) async {
      await _open(t, size: size);
      expect(find.text('Task A'), findsOneWidget);
      await _tab(t, _l.projectTabList);
      expect(find.byKey(const ValueKey('row-a')), findsOneWidget);
      await _tab(t, _l.projectTabMembers);
      expect(find.byKey(const ValueKey('member-2')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('the chat tab is a placeholder', (t) async {
    await _open(t);
    await _tab(t, _l.projectTabChat);
    expect(find.text(_l.comingSoonTitle), findsOneWidget);
  });

  testWidgets('files tab filters by type and searches', (t) async {
    final f = await _open(
      t,
      seed: (s) => s.projectFiles.addAll([
        {
          'id': 'f1',
          'name': 'photo.png',
          'content_type': 'image/png',
          'size': 2048,
          'task_id': 'a',
          'task_title': 'Task A',
          'uploaded_by': me,
          'created_at': '2026-01-01T00:00:00Z',
        },
        {
          'id': 'f2',
          'name': 'spec.pdf',
          'content_type': 'application/pdf',
          'size': 10,
          'task_id': 'a',
          'task_title': 'Task A',
          'uploaded_by': me,
          'created_at': '2026-01-01T00:00:00Z',
        },
      ]),
    );
    await _tab(t, _l.projectTabFiles);
    expect(find.text('photo.png'), findsOneWidget);
    expect(find.text('spec.pdf'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('file-type-image')));
    await t.pumpAndSettle();
    expect(find.text('spec.pdf'), findsNothing);
    expect(
      f.server.where('GET', '/files').last.url.queryParameters['type'],
      'image',
    );
    await t.enterText(find.byKey(const ValueKey('files-search')), 'ph');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pumpAndSettle();
    expect(f.server.where('GET', '/files').last.url.queryParameters['q'], 'ph');
  });

  testWidgets('files tab explains itself when the endpoint is missing', (
    t,
  ) async {
    await _open(t, seed: (s) => s.optionalEndpoints = false);
    await _tab(t, _l.projectTabFiles);
    expect(find.text(_l.projectFilesUnavailable), findsOneWidget);
  });

  testWidgets('settings: archive confirms, copy is hidden after a 404', (
    t,
  ) async {
    final f = await _open(t, seed: (s) => s.optionalEndpoints = false);
    await _tab(t, _l.projectTabMembers);
    await t.ensureVisible(find.byKey(const ValueKey('project-copy')));
    await t.tap(find.byKey(const ValueKey('project-copy')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('prompt-confirm')));
    await t.pumpAndSettle();
    expect(find.text(_l.projectCopyUnavailable), findsOneWidget);
    expect(find.byKey(const ValueKey('project-copy')), findsNothing);

    await t.ensureVisible(find.byKey(const ValueKey('project-archive')));
    await t.tap(find.byKey(const ValueKey('project-archive')));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, _l.projectArchive));
    await t.pumpAndSettle();
    expect(f.server.lastBody('PATCH', '/projects/p1'), {'status': 'archived'});
  });

  testWidgets('settings: copy with structure posts the new name', (t) async {
    final f = await _open(t);
    await _tab(t, _l.projectTabMembers);
    await t.ensureVisible(find.byKey(const ValueKey('project-copy')));
    await t.tap(find.byKey(const ValueKey('project-copy')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('prompt-field')), 'Alpha 2');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('prompt-confirm')));
    await t.pumpAndSettle();
    expect(f.server.lastBody('POST', '/projects/p1/copy'), {'name': 'Alpha 2'});
    expect(find.text(_l.projectCopied('Alpha 2')), findsOneWidget);
  });

  group('calendar', () {
    Future<(ProjectCalendarController, ProjectsFixture)> calendar(
      WidgetTester t,
      DateTime today, {
      List<Map<String, dynamic>> tasks = const [],
    }) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(375, 812);
      addTearDown(t.view.reset);
      final f = projectsFixture();
      f.server.calendar = tasks;
      final c = ProjectCalendarController(f.env, 'p1', today: today);
      addTearDown(c.dispose);
      await t.pumpWidget(
        faApp(
          ProjectCalendarView(controller: c, onOpenTask: (_) {}, today: today),
        ),
      );
      await c.load();
      await t.pumpAndSettle();
      return (c, f);
    }

    testWidgets('shows counts per day and the tasks of a tapped day', (
      t,
    ) async {
      // 2026-03-25 is 5 Farvardin 1405.
      final (c, _) = await calendar(
        t,
        DateTime(2026, 3, 25),
        tasks: [
          briefTask('t1', title: 'Due soon', dueAt: '2026-03-25T08:00:00'),
          briefTask('t2', title: 'Other', dueAt: '2026-03-26T08:00:00'),
        ],
      );
      expect(find.byKey(const ValueKey('cal-title')), findsOneWidget);
      expect(find.text('فروردین ۱۴۰۵'), findsOneWidget);
      expect(find.byKey(const ValueKey('cal-count-5')), findsOneWidget);
      expect(find.byKey(const ValueKey('cal-count-6')), findsOneWidget);
      expect(find.text('Due soon'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('cal-day-6')));
      await t.pumpAndSettle();
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('Due soon'), findsNothing);
      expect(c.selectedDay, 6);
    });

    testWidgets('navigates across the Jalali year boundary', (t) async {
      final (_, f) = await calendar(t, DateTime(2026, 3, 25));
      await t.tap(find.byKey(const ValueKey('cal-prev')));
      await t.pumpAndSettle();
      expect(find.text('اسفند ۱۴۰۴'), findsOneWidget);
      final q = f.server.calls.last.url.queryParameters;
      expect(DateTime.parse(q['to']!).toLocal(), DateTime(2026, 3, 21));
      // Esfand 1404 has 29 days.
      expect(find.byKey(const ValueKey('cal-day-29')), findsOneWidget);
      expect(find.byKey(const ValueKey('cal-day-30')), findsNothing);
      await t.tap(find.byKey(const ValueKey('cal-next')));
      await t.pumpAndSettle();
      expect(find.text('فروردین ۱۴۰۵'), findsOneWidget);
    });
  });
}
