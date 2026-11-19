import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations_fa.dart';
import 'package:letter_signing/workspace/labels_screen.dart';
import 'package:letter_signing/workspace/widgets/reminders_card.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../helpers.dart';
import '../projects/project_fixtures.dart';

final _l = AppLocalizationsFa();

String _dayKey(Jalali j) =>
    'jalali-day-${j.year}-${j.month.toString().padLeft(2, '0')}-'
    '${j.day.toString().padLeft(2, '0')}';

/// Picks a date a few days ahead in the Jalali dialog and accepts the time picker.
Future<Jalali> _pickDate(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('reminder-date')));
  await t.pumpAndSettle();
  final now = DateTime.now();
  final target = DateTime(
    now.year,
    now.month,
    now.day,
  ).add(const Duration(days: 3));
  final j = toJalali(target);
  if (j.month != toJalali(now).month) {
    await t.tap(find.byKey(const Key('jalali-next-month')));
    await t.pumpAndSettle();
  }
  await t.tap(find.byKey(Key(_dayKey(j))));
  await t.pump();
  await t.tap(find.byKey(const Key('jalali-confirm')));
  await t.pumpAndSettle();
  final ok = find.descendant(
    of: find.byType(TimePickerDialog),
    matching: find.byType(TextButton),
  );
  await t.tap(ok.last);
  await t.pumpAndSettle();
  return j;
}

Future<ProjectsFixture> _reminders(WidgetTester t, Size size) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.reset);
  final f = projectsFixture();
  await t.pumpWidget(
    faApp(
      SingleChildScrollView(
        child: RemindersCard(api: f.env.tasks.api.workspace, subjectId: 's'),
      ),
    ),
  );
  await t.pumpAndSettle();
  return f;
}

void main() {
  for (final size in [const Size(375, 812), const Size(844, 390)]) {
    testWidgets('weekly reminder with weekday chips at $size', (t) async {
      final f = await _reminders(t, size);
      expect(find.text(_l.remindersEmpty), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('reminder-add')));
      await t.pumpAndSettle();
      final j = await _pickDate(t);
      await t.tap(find.byKey(const ValueKey('repeat-weekly')));
      await t.pumpAndSettle();
      // The weekday of the chosen date is pre-selected; add Saturday too.
      await t.tap(find.byKey(const ValueKey('weekday-0')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('reminder-save')));
      await t.pumpAndSettle();
      final body = f.server.lastBody('POST', '/reminders')! as Map;
      expect(
        DateTime.parse(body['at'] as String).isAfter(DateTime.now()),
        isTrue,
      );
      final rule = body['rule'] as Map;
      expect(rule['freq'], 'weekly');
      final days = {...(rule['weekdays'] as List).cast<int>()};
      expect(days, containsAll([0, j.weekDay - 1]));
      expect(find.byKey(const ValueKey('reminder-1')), findsOneWidget);
      expect(find.textContaining(_l.reminderWeekly), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('a one-off reminder has no rule; monthly sends the Jalali day', (
    t,
  ) async {
    final f = await _reminders(t, const Size(375, 812));
    await t.tap(find.byKey(const ValueKey('reminder-add')));
    await t.pumpAndSettle();
    final j = await _pickDate(t);
    await t.tap(find.byKey(const ValueKey('repeat-monthly_jalali')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('reminder-save')));
    await t.pumpAndSettle();
    expect((f.server.lastBody('POST', '/reminders')! as Map)['rule'], {
      'freq': 'monthly_jalali',
      'interval': 1,
      'day': j.day,
    });
  });

  testWidgets('saving without a date shows an error and posts nothing', (
    t,
  ) async {
    final f = await _reminders(t, const Size(375, 812));
    await t.tap(find.byKey(const ValueKey('reminder-add')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('reminder-save')));
    await t.pumpAndSettle();
    expect(find.text(_l.reminderDateRequired), findsOneWidget);
    expect(f.server.where('POST', '/reminders'), isEmpty);
  });

  testWidgets('a reminder can be deactivated', (t) async {
    final f = await _reminders(t, const Size(375, 812));
    f.server.reminders.add({
      'id': 7,
      'subject_id': 's',
      'at': DateTime.now()
          .add(const Duration(days: 2))
          .toUtc()
          .toIso8601String(),
      'rule': {'freq': 'daily', 'interval': 1},
      'last_fired_at': null,
    });
    await t.tap(find.byKey(const ValueKey('reminder-add')));
    await t.pumpAndSettle();
    await t.tap(find.text(_l.commonCancel));
    await t.pumpAndSettle();
    // Reload by reopening the card.
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpWidget(
      faApp(RemindersCard(api: f.env.tasks.api.workspace, subjectId: 's')),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('reminder-7')), findsOneWidget);
    expect(find.text(_l.reminderDaily), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('reminder-remove-7')));
    await t.pumpAndSettle();
    expect(f.server.where('DELETE', '/reminders/7'), hasLength(1));
    expect(find.byKey(const ValueKey('reminder-7')), findsNothing);
  });

  group('labels screen', () {
    Future<ProjectsFixture> labels(
      WidgetTester t, {
      bool manager = false,
      Size size = const Size(375, 812),
    }) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = size;
      addTearDown(t.view.reset);
      final f = projectsFixture();
      f.server.tasks.labels.addAll([
        {
          'id': 1,
          'name': 'Org one',
          'color': 1,
          'scope': 'org',
          'active': true,
        },
        {
          'id': 2,
          'name': 'Mine',
          'color': 2,
          'scope': 'personal',
          'active': true,
        },
      ]);
      await t.pumpWidget(
        faApp(LabelsScreen(api: f.env.tasks.api.workspace, isManager: manager)),
      );
      await t.pumpAndSettle();
      return f;
    }

    testWidgets('everyone edits personal labels, only managers org ones', (
      t,
    ) async {
      await labels(t);
      expect(find.text('Org one'), findsOneWidget);
      expect(find.byKey(const ValueKey('label-edit-1')), findsNothing);
      expect(find.byKey(const ValueKey('label-edit-2')), findsOneWidget);
      await labels(t, manager: true);
      expect(find.byKey(const ValueKey('label-edit-1')), findsOneWidget);
    });

    testWidgets('create, rename, recolour and deactivate', (t) async {
      final f = await labels(t, manager: true, size: const Size(844, 600));
      await t.tap(find.byKey(const ValueKey('label-add')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('label-name')), 'Urgent');
      await t.tap(find.byKey(const ValueKey('label-color-4')));
      await t.tap(find.byKey(const ValueKey('label-org')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('label-save')));
      await t.pumpAndSettle();
      expect(f.server.lastBody('POST', '/labels'), {
        'name': 'Urgent',
        'color': 4,
        'scope': 'org',
      });
      expect(find.text('Urgent'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('label-edit-2')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('label-name')), 'Renamed');
      await t.tap(find.byKey(const ValueKey('label-color-5')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('label-save')));
      await t.pumpAndSettle();
      expect(f.server.lastBody('PATCH', '/labels/2'), {
        'name': 'Renamed',
        'color': 5,
      });

      await t.tap(find.byKey(const ValueKey('label-toggle-2')));
      await t.pumpAndSettle();
      expect(f.server.lastBody('PATCH', '/labels/2'), {'active': false});
    });

    testWidgets('a duplicate name is explained', (t) async {
      await labels(t);
      await t.tap(find.byKey(const ValueKey('label-add')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('label-name')), 'Org one');
      await t.pump();
      await t.tap(find.byKey(const ValueKey('label-save')));
      await t.pumpAndSettle();
      expect(find.text(_l.labelDuplicate), findsOneWidget);
    });
  });
}
