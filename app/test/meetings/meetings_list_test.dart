import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/meetings/meetings_api.dart';
import 'package:letter_signing/meetings/meetings_controller.dart';
import 'package:letter_signing/meetings/meetings_screen.dart';
import 'package:letter_signing/meetings/models.dart';
import 'package:letter_signing/meetings/meeting_templates_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import '../letters/fakes.dart';
import 'meeting_fixtures.dart';

const _sizes = [Size(375, 812), Size(844, 390)];

void main() {
  test(
    'upcoming meetings come first, soonest first, then past newest first',
    () {
      final now = DateTime.utc(2026, 5, 1);
      MeetingBrief at(String id, DateTime? d) =>
          MeetingBrief(id: id, subjectId: 's', title: id, startsAt: d);
      final sorted = sortUpcomingFirst([
        at('past-old', DateTime.utc(2026, 1, 1)),
        at('later', DateTime.utc(2026, 9, 1)),
        at('none', null),
        at('soon', DateTime.utc(2026, 6, 1)),
        at('past-new', DateTime.utc(2026, 4, 1)),
      ], now: now);
      expect(
        [for (final m in sorted) m.id],
        ['soon', 'later', 'past-new', 'past-old', 'none'],
      );
    },
  );

  test('MeetingFilter builds the query and counts active filters', () {
    const f = MeetingFilter(status: 'held', mine: true);
    expect(f.activeCount, 2);
    final q = f.toQuery();
    expect(q['status'], 'held');
    expect(q['mine'], 'true');
    expect(const MeetingFilter().activeCount, 0);
  });

  testWidgets('list shows cards with status pills and the date in Jalali', (
    t,
  ) async {
    final s = FakeMeetingsServer()
      ..list = [
        meetingBrief('m1', title: 'Weekly sync'),
        meetingBrief(
          'm2',
          title: 'Old review',
          status: 'closed',
          startsAt: '2020-01-01T08:00:00Z',
        ),
      ];
    await useTallSurface(t, const Size(375, 812));
    await t.pumpWidget(
      faMaterial(home: MeetingsScreen(env: meetingsEnv(s).env)),
    );
    await t.pumpAndSettle();
    expect(find.text('Weekly sync'), findsOneWidget);
    expect(find.text('برنامه‌ریزی‌شده'), findsOneWidget);
    expect(find.text('بسته‌شده'), findsOneWidget);
    expect(find.textContaining('۱۳۹۸'), findsOneWidget);
    expect(
      t.getTopLeft(find.text('Weekly sync')).dy <
          t.getTopLeft(find.text('Old review')).dy,
      isTrue,
    );
  });

  testWidgets('filters send status, kind, mine and the date range', (t) async {
    final s = FakeMeetingsServer();
    await useTallSurface(t, const Size(375, 900));
    await t.pumpWidget(
      faMaterial(home: MeetingsScreen(env: meetingsEnv(s).env)),
    );
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('فیلترها'));
    await t.pumpAndSettle();
    await t.tap(find.byType(DropdownButtonFormField<String>).first);
    await t.pumpAndSettle();
    await t.tap(find.text('برگزارشده').last);
    await t.pumpAndSettle();
    await t.tap(find.byType(SwitchListTile));
    await t.pump();
    await t.tap(find.text('اعمال'));
    await t.pumpAndSettle();
    final req = s.calls.lastWhere((c) => c.url.path == '/api/meetings');
    expect(req.url.queryParameters['status'], 'held');
    expect(req.url.queryParameters['mine'], 'true');
  });

  testWidgets('search submits q', (t) async {
    final s = FakeMeetingsServer();
    await useTallSurface(t, const Size(375, 812));
    await t.pumpWidget(
      faMaterial(home: MeetingsScreen(env: meetingsEnv(s).env)),
    );
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'budget');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pumpAndSettle();
    final req = s.calls.lastWhere((c) => c.url.path == '/api/meetings');
    expect(req.url.queryParameters['q'], 'budget');
  });

  testWidgets('a live meetings event reloads the list', (t) async {
    final s = FakeMeetingsServer();
    final e = meetingsEnv(s);
    await t.pumpWidget(faMaterial(home: MeetingsScreen(env: e.env)));
    await t.pumpAndSettle();
    final before = s.where('GET', '/meetings').length;
    e.live.push({
      'type': 'ws',
      'stream': 'w',
      'module': 'meetings',
      'kind': 'meeting.updated',
    });
    await t.pumpAndSettle();
    expect(s.where('GET', '/meetings').length, before + 1);
  });

  testWidgets('empty and error states', (t) async {
    final s = FakeMeetingsServer()..list = [];
    await t.pumpWidget(
      faMaterial(home: MeetingsScreen(env: meetingsEnv(s).env)),
    );
    await t.pumpAndSettle();
    expect(find.text('جلسه‌ای وجود ندارد'), findsOneWidget);
  });

  for (final size in _sizes) {
    testWidgets('list fits ${size.width}x${size.height}', (t) async {
      final s = FakeMeetingsServer()
        ..list = [
          meetingBrief(
            'm1',
            title:
                'A very long meeting title that has to wrap on small screens',
            kind: 'organizational',
          ),
        ];
      await useTallSurface(t, size);
      await t.pumpWidget(
        faMaterial(home: MeetingsScreen(env: meetingsEnv(s).env)),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('templates screen renames and deactivates', (t) async {
    final s = FakeMeetingsServer();
    s.templates.add({
      'id': 7,
      'name': 'Board',
      'scope': 'personal',
      'owner_id': 2,
      'data': {
        'kind': 'simple',
        'location': '',
        'description': '',
        'attendees': <Object>[],
      },
      'active': true,
    });
    await useTallSurface(t, const Size(375, 812));
    await t.pumpWidget(
      faMaterial(home: MeetingTemplatesScreen(env: meetingsEnv(s).env)),
    );
    await t.pumpAndSettle();
    expect(find.text('Board'), findsOneWidget);
    await t.tap(find.byTooltip('تغییر نام'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Board 2');
    await t.tap(find.widgetWithText(FilledButton, 'ذخیره'));
    await t.pumpAndSettle();
    expect(s.lastBody('PATCH', '/meeting-templates/7'), {'name': 'Board 2'});
    await t.tap(find.byTooltip('غیرفعال کردن'));
    await t.pumpAndSettle();
    expect(s.lastBody('PATCH', '/meeting-templates/7'), {'active': false});
    expect(find.text('غیرفعال'), findsOneWidget);
  });
}
