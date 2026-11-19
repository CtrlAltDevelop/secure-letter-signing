import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/meetings/meeting_form_screen.dart';
import 'package:letter_signing/meetings/models.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import '../letters/fakes.dart';
import 'meeting_fixtures.dart';

const _sizes = [Size(375, 812), Size(844, 390)];

Future<void> _open(
  WidgetTester t,
  FakeMeetingsServer s, {
  MeetingOut? meeting,
  bool manager = false,
}) async {
  await t.pumpWidget(
    faMaterial(
      home: MeetingFormScreen(
        env: meetingsEnv(s, isManager: manager).env,
        meeting: meeting,
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  test('an organizational draft needs exactly one chair and one secretary', () {
    const org = MeetingDraft(
      title: 'x',
      kind: MeetingKind.organizational,
      attendees: [AttendeeDraft(userId: 2, role: AttendeeRole.chair)],
    );
    expect(org.issues(schedule: false), {MeetingIssue.needOneSecretary});
    final ok = org.copyWith(
      attendees: [
        ...org.attendees,
        const AttendeeDraft(userId: 3, role: AttendeeRole.secretary),
      ],
    );
    expect(ok.issues(schedule: false), isEmpty);
    expect(ok.issues(schedule: true), {MeetingIssue.startMissing});
    expect(const MeetingDraft(title: ' ').issues(schedule: false), {
      MeetingIssue.titleMissing,
    });
  });

  test('toCreateJson converts times to UTC and guests carry a name', () {
    final d = MeetingDraft(
      title: ' T ',
      startsAt: DateTime.utc(2026, 5, 1, 8),
      attendees: const [
        AttendeeDraft(userId: 2, role: AttendeeRole.chair),
        AttendeeDraft(guestName: 'Zed', role: AttendeeRole.guest),
      ],
    );
    final j = d.toCreateJson(schedule: true);
    expect(j['title'], 'T');
    expect(j['status'], 'scheduled');
    expect(j['starts_at'], '2026-05-01T08:00:00.000Z');
    expect(j['attendees'], [
      {'user_id': 2, 'role': 'chair'},
      {'guest_name': 'Zed', 'role': 'guest'},
    ]);
  });

  testWidgets('saving a draft posts the title and attendees', (t) async {
    final s = FakeMeetingsServer();
    await useTallSurface(t, const Size(375, 1400));
    await _open(t, s);
    await t.enterText(find.widgetWithText(TextField, 'عنوان'), 'Kickoff');
    await t.enterText(find.widgetWithText(TextField, 'مکان'), 'Room 2');
    await t.pump();
    await t.tap(find.text('ذخیره پیش‌نویس'));
    await t.pumpAndSettle();
    final body = s.lastBody('POST', '/meetings') as Map;
    expect(body['title'], 'Kickoff');
    expect(body['location'], 'Room 2');
    expect(body['status'], 'draft');
    expect(body['kind'], 'simple');
    expect(body['attendees'], [
      {'user_id': 2, 'role': 'chair'},
    ]);
  });

  testWidgets('scheduling without a start time is explained', (t) async {
    final s = FakeMeetingsServer();
    await useTallSurface(t, const Size(375, 1400));
    await _open(t, s);
    await t.enterText(find.widgetWithText(TextField, 'عنوان'), 'Kickoff');
    await t.pump();
    await t.tap(find.text('ذخیره و برنامه‌ریزی'));
    await t.pumpAndSettle();
    expect(find.text('زمان شروع را مشخص کنید'), findsOneWidget);
    expect(s.where('POST', '/meetings'), isEmpty);
  });

  testWidgets('organizational asks for a secretary; a guest can be added', (
    t,
  ) async {
    final s = FakeMeetingsServer();
    await useTallSurface(t, const Size(375, 1400));
    await _open(t, s);
    await t.tap(find.text('سازمانی'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'عنوان'), 'Board');
    await t.tap(find.text('افزودن مهمان'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'نام مهمان'), 'Zed');
    await t.tap(find.text('تأیید'));
    await t.pumpAndSettle();
    expect(find.text('Zed'), findsOneWidget);
    expect(find.text('مهمان بیرونی'), findsOneWidget);
    await t.tap(find.text('ذخیره پیش‌نویس'));
    await t.pumpAndSettle();
    expect(find.text('جلسه سازمانی دقیقاً یک دبیر لازم دارد'), findsOneWidget);
    expect(s.where('POST', '/meetings'), isEmpty);
  });

  testWidgets('changing an attendee role updates the chip', (t) async {
    final s = FakeMeetingsServer();
    await useTallSurface(t, const Size(375, 1400));
    await _open(t, s);
    await t.tap(find.text('رئیس جلسه'));
    await t.pumpAndSettle();
    await t.tap(find.text('دبیر').last);
    await t.pumpAndSettle();
    expect(find.text('دبیر'), findsOneWidget);
  });

  testWidgets('a template fills the form; save as template posts data', (
    t,
  ) async {
    final s = FakeMeetingsServer();
    s.templates.add({
      'id': 4,
      'name': 'Weekly',
      'scope': 'org',
      'owner_id': null,
      'data': {
        'kind': 'simple',
        'location': 'HQ',
        'description': 'Agenda',
        'attendees': [
          {'user_id': 3, 'role': 'member'},
        ],
      },
      'active': true,
    });
    await useTallSurface(t, const Size(375, 1600));
    await _open(t, s, manager: true);
    await t.tap(find.byType(DropdownButtonFormField<int>));
    await t.pumpAndSettle();
    await t.tap(find.text('Weekly').last);
    await t.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'HQ'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);

    await t.tap(find.text('ذخیره به‌عنوان الگو'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'نام الگو'), 'My copy');
    await t.tap(find.byType(SwitchListTile));
    await t.pump();
    await t.tap(find.widgetWithText(FilledButton, 'ذخیره'));
    await t.pumpAndSettle();
    final body = s.lastBody('POST', '/meeting-templates') as Map;
    expect(body['name'], 'My copy');
    expect(body['scope'], 'org');
    expect((body['data'] as Map)['location'], 'HQ');
  });

  testWidgets('editing patches the fields and replaces the attendees', (
    t,
  ) async {
    final s = FakeMeetingsServer();
    s.meeting = meetingFull('m1', status: 'draft');
    final meeting = MeetingOut.fromJson(s.meeting);
    await useTallSurface(t, const Size(375, 1400));
    await _open(t, s, meeting: meeting);
    await t.enterText(find.widgetWithText(TextField, 'Weekly sync'), 'Renamed');
    await t.pump();
    await t.tap(find.text('ذخیره و برنامه‌ریزی'));
    await t.pumpAndSettle();
    expect((s.lastBody('PATCH', '/meetings/m1') as Map)['title'], 'Renamed');
    expect(s.where('PUT', '/attendees'), hasLength(1));
    expect(s.where('POST', '/schedule'), hasLength(1));
  });

  for (final size in _sizes) {
    testWidgets('form fits ${size.width}x${size.height}', (t) async {
      final s = FakeMeetingsServer();
      await useTallSurface(t, size);
      await _open(t, s);
      expect(t.takeException(), isNull);
    });
  }
}
