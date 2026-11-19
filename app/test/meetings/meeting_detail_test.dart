import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/meetings/meeting_detail_screen.dart';
import 'package:letter_signing/meetings/meetings_env.dart';
import 'package:letter_signing/tasks/task_detail_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import '../letters/fakes.dart';
import '../tasks/task_fixtures.dart';
import 'meeting_fixtures.dart';

const _sizes = [Size(375, 812), Size(844, 390)];

Future<MeetingsEnv> _open(
  WidgetTester t,
  FakeMeetingsServer s, {
  Size size = const Size(375, 2400),
  FakeBiometrics? biometrics,
  bool pump = true,
}) async {
  await useTallSurface(t, size);
  final e = meetingsEnv(s, biometrics: biometrics);
  await t.pumpWidget(
    faMaterial(
      home: MeetingDetailScreen(env: e.env, meetingId: 'm1'),
    ),
  );
  if (pump) await t.pumpAndSettle();
  return e.env;
}

void main() {
  testWidgets('shows info, attendees with roles, minutes and signatures', (
    t,
  ) async {
    final s = FakeMeetingsServer();
    s.meeting = meetingFull(
      'm1',
      description: 'We agreed on the plan',
      attendees: [
        attendeeJson(1, role: 'chair', attendance: 'present'),
        attendeeJson(2, user: bob, role: 'member'),
        attendeeJson(3, user: null, guest: 'Zed', role: 'guest'),
      ],
      signatures: [
        meetingSignature(1),
        meetingSignature(2, user: bob, stale: true, valid: false),
      ],
    );
    await _open(t, s);
    expect(find.text('Weekly sync'), findsOneWidget);
    expect(find.text('Room 1'), findsOneWidget);
    expect(find.text('رئیس جلسه'), findsOneWidget);
    expect(find.text('حاضر'), findsOneWidget);
    expect(find.textContaining('Zed'), findsOneWidget);
    expect(find.text('We agreed on the plan'), findsOneWidget);
    expect(find.text('منسوخ'), findsOneWidget);
    expect(find.text('نامعتبر'), findsOneWidget);
    expect(find.text('معتبر'), findsOneWidget);
  });

  testWidgets('the chair marks attendance', (t) async {
    final s = FakeMeetingsServer();
    await _open(t, s);
    await t.tap(find.text('نامشخص').last);
    await t.pumpAndSettle();
    await t.tap(find.text('غایب').last);
    await t.pumpAndSettle();
    expect(s.lastBody('POST', '/attendance'), {
      'attendee_id': 2,
      'attendance': 'absent',
    });
    expect(find.text('غایب'), findsOneWidget);
  });

  testWidgets('attendance cannot be marked without the run right', (t) async {
    final s = FakeMeetingsServer();
    s.meeting = meetingFull('m1', can: canFlags(run: false, chair: false));
    await _open(t, s);
    await t.tap(find.text('نامشخص').last, warnIfMissed: false);
    await t.pumpAndSettle();
    expect(find.text('غایب'), findsNothing);
  });

  testWidgets('lifecycle buttons follow the status and the can flags', (
    t,
  ) async {
    final s = FakeMeetingsServer();
    s.meeting = meetingFull('m1', status: 'draft');
    await _open(t, s);
    expect(find.byKey(const ValueKey('action-schedule')), findsOneWidget);
    expect(find.byKey(const ValueKey('action-cancel')), findsOneWidget);
    expect(find.byKey(const ValueKey('action-hold')), findsNothing);
    await t.tap(find.byKey(const ValueKey('action-schedule')));
    await t.pumpAndSettle();
    expect(s.where('POST', '/schedule'), hasLength(1));
    expect(find.byKey(const ValueKey('action-hold')), findsOneWidget);
    expect(find.byKey(const ValueKey('action-remind')), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('action-hold')));
    await t.pumpAndSettle();
    expect(s.where('POST', '/hold'), hasLength(1));
    expect(find.byKey(const ValueKey('action-close')), findsOneWidget);
    expect(find.byKey(const ValueKey('action-reopen')), findsNothing);

    await t.tap(find.byKey(const ValueKey('action-close')));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'بستن صورتجلسه').last);
    await t.pumpAndSettle();
    expect(s.where('POST', '/close'), hasLength(1));
    expect(find.byKey(const ValueKey('action-reopen')), findsOneWidget);
  });

  testWidgets('a non-chair sees no lifecycle buttons', (t) async {
    final s = FakeMeetingsServer();
    s.meeting = meetingFull(
      'm1',
      can: canFlags(manage: false, chair: false, record: false, run: false),
    );
    await _open(t, s);
    expect(find.byKey(const ValueKey('action-hold')), findsNothing);
    expect(find.byKey(const ValueKey('action-cancel')), findsNothing);
    expect(find.byKey(const ValueKey('action-sms')), findsNothing);
  });

  testWidgets('cancel asks for confirmation', (t) async {
    final s = FakeMeetingsServer();
    await _open(t, s);
    await t.tap(find.byKey(const ValueKey('action-cancel')));
    await t.pumpAndSettle();
    await t.tap(find.text('انصراف'));
    await t.pumpAndSettle();
    expect(s.where('POST', '/cancel'), isEmpty);
    await t.tap(find.byKey(const ValueKey('action-cancel')));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'لغو جلسه'));
    await t.pumpAndSettle();
    expect(s.where('POST', '/cancel'), hasLength(1));
  });

  testWidgets('a server refusal is shown', (t) async {
    final s = FakeMeetingsServer();
    s.meeting = meetingFull('m1', status: 'draft');
    await _open(t, s);
    s.failNext = 422;
    s.failDetail = 'A scheduled meeting needs a start time';
    await t.tap(find.byKey(const ValueKey('action-schedule')));
    await t.pumpAndSettle();
    expect(find.textContaining('needs a start time'), findsOneWidget);
  });

  testWidgets('resolutions: add with an owner, open its task, deactivate', (
    t,
  ) async {
    final s = FakeMeetingsServer();
    final tasks = FakeTasksServer(
      tasks: [fullTask('tsk-1', title: 'Follow up')],
    );
    await useTallSurface(t, const Size(375, 2400));
    final f = fakeApi(s.handle);
    final tf = tasksFixture(server: tasks);
    final env = MeetingsEnv(
      api: meetingsEnv(s).env.api,
      live: FakeLive(f.client),
      userId: 2,
      tasks: tf.env,
      biometrics: FakeBiometrics(),
    );
    await t.pumpWidget(
      faMaterial(
        home: MeetingDetailScreen(env: env, meetingId: 'm1'),
      ),
    );
    await t.pumpAndSettle();

    await t.tap(find.text('افزودن مصوبه'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'متن مصوبه'), 'Ship v2');
    await t.tap(find.text('افزودن').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Bob').last);
    await t.tap(find.text('تأیید'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'ذخیره'));
    await t.pumpAndSettle();
    expect(s.lastBody('POST', '/resolutions'), {
      'text': 'Ship v2',
      'due_at': null,
      'owner_ids': [3],
    });
    expect(find.text('Ship v2'), findsOneWidget);

    await t.tap(find.textContaining('وظیفه (۴۰'));
    await t.pumpAndSettle();
    expect(find.byType(TaskDetailScreen), findsOneWidget);
    Navigator.of(t.element(find.byType(TaskDetailScreen))).pop();
    await t.pumpAndSettle();

    await t.tap(find.byTooltip('گزینه‌ها'));
    await t.pumpAndSettle();
    await t.tap(find.text('غیرفعال کردن'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'غیرفعال کردن'));
    await t.pumpAndSettle();
    expect(s.lastBody('PATCH', '/resolutions/50'), {'active': false});
    expect(find.text('Ship v2'), findsNothing);
  });

  testWidgets('editing the minutes patches the description', (t) async {
    final s = FakeMeetingsServer();
    await _open(t, s);
    await t.tap(find.text('ویرایش متن'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'صورتجلسه'), 'New text');
    await t.tap(find.widgetWithText(FilledButton, 'ذخیره'));
    await t.pumpAndSettle();
    expect(s.lastBody('PATCH', '/meetings/m1'), {
      'description': {'text': 'New text'},
    });
    expect(find.text('New text'), findsOneWidget);
  });

  testWidgets('signing: a rejection needs a note, then the PIN is posted', (
    t,
  ) async {
    final s = FakeMeetingsServer();
    s.meeting = meetingFull('m1', status: 'held', can: canFlags(sign: true));
    await _open(t, s);
    await t.tap(find.text('امضای صورتجلسه').last);
    await t.pumpAndSettle();
    await t.tap(find.text('رد'));
    await t.pump();
    await t.enterText(find.widgetWithText(TextFormField, 'رمز امضا'), '123456');
    await t.tap(find.text('امضا با رمز'));
    await t.pumpAndSettle();
    expect(find.text('برای رد کردن باید یادداشت بنویسید.'), findsOneWidget);
    expect(s.where('POST', '/sign'), isEmpty);

    await t.enterText(
      find.widgetWithText(TextField, 'یادداشت (برای رد الزامی است)'),
      'no',
    );
    await t.tap(find.text('امضا با رمز'));
    await t.pumpAndSettle();
    expect(s.lastBody('POST', '/sign'), {
      'decision': 'rejected',
      'note': 'no',
      'pin': '123456',
    });
    expect(find.text('امضای صورتجلسه'), findsNothing);
    expect(find.text('رد شد'), findsOneWidget);
  });

  testWidgets('signing with biometrics posts to sign-biometric', (t) async {
    final s = FakeMeetingsServer();
    s.meeting = meetingFull('m1', status: 'held', can: canFlags(sign: true));
    final bio = FakeBiometrics();
    await _open(t, s, biometrics: bio);
    await t.tap(find.text('امضای صورتجلسه').last);
    await t.pumpAndSettle();
    await t.tap(find.text('اثر انگشت / چهره'));
    await t.pumpAndSettle();
    expect(bio.reasons, hasLength(1));
    expect(s.lastBody('POST', '/sign-biometric'), {
      'decision': 'approved',
      'note': '',
    });
  });

  testWidgets('no sign button before held or after signing', (t) async {
    final s = FakeMeetingsServer();
    s.meeting = meetingFull('m1', can: canFlags(sign: true));
    await _open(t, s);
    expect(find.text('امضای صورتجلسه'), findsNothing);

    s.meeting = meetingFull(
      'm1',
      status: 'held',
      can: canFlags(sign: true),
      signatures: [meetingSignature(1)],
    );
    await _open(t, s);
    expect(find.text('امضای صورتجلسه'), findsNothing);
  });

  testWidgets('reminders and SMS show their results', (t) async {
    final s = FakeMeetingsServer();
    await _open(t, s);
    await t.tap(find.byKey(const ValueKey('action-remind')));
    await t.pumpAndSettle();
    await t.tap(find.text('تأیید'));
    await t.pumpAndSettle();
    expect(s.lastBody('POST', '/remind'), {'offset_minutes': 60});
    expect(find.text('۲ یادآوری ثبت شد'), findsOneWidget);
    await t.pump(const Duration(seconds: 6));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('action-sms')));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'متن پیامک'), 'See you');
    await t.pump();
    await t.tap(find.text('ارسال'));
    await t.pumpAndSettle();
    expect(s.lastBody('POST', '/sms'), {'text': 'See you'});
    expect(find.text('ارسال‌شده: ۲، بدون شماره: ۱'), findsOneWidget);
  });

  testWidgets('comments, files and history tabs load through subjects', (
    t,
  ) async {
    final s = FakeMeetingsServer();
    await _open(t, s);
    expect(s.where('GET', '/subjects/ms-m1/comments'), hasLength(1));
    await t.tap(find.textContaining('پرونده‌ها'));
    await t.pumpAndSettle();
    expect(s.where('GET', '/subjects/ms-m1/files'), hasLength(1));
    await t.tap(find.text('تاریخچه'));
    await t.pumpAndSettle();
    expect(s.where('GET', '/subjects/ms-m1/history'), hasLength(1));
  });

  testWidgets('a live event of the subject reloads the meeting', (t) async {
    final s = FakeMeetingsServer();
    final f = fakeApi(s.handle);
    final live = FakeLive(f.client);
    final env = MeetingsEnv(
      api: meetingsEnv(s).env.api,
      live: live,
      userId: 2,
      tasks: tasksFixture().env,
    );
    await t.pumpWidget(
      faMaterial(
        home: MeetingDetailScreen(env: env, meetingId: 'm1'),
      ),
    );
    await t.pumpAndSettle();
    final before = s.where('GET', '/meetings/m1').length;
    live.push({
      'type': 'ws',
      'stream': 'w',
      'module': 'meetings',
      'kind': 'meeting.updated',
      'subject_id': 'ms-m1',
    });
    await t.pumpAndSettle();
    expect(s.where('GET', '/meetings/m1').length, before + 1);
  });

  for (final size in _sizes) {
    testWidgets('detail fits ${size.width}x${size.height}', (t) async {
      final s = FakeMeetingsServer();
      s.meeting = meetingFull(
        'm1',
        status: 'held',
        can: canFlags(sign: true),
        description: 'Long minutes ' * 30,
        resolutions: [
          resolutionJson(
            1,
            'A resolution with a rather long text that wraps',
            owners: [3],
            taskId: 'tsk-1',
            due: '2026-06-01T00:00:00Z',
          ),
        ],
        signatures: [meetingSignature(1, user: bob)],
      );
      await useTallSurface(t, size);
      final e = meetingsEnv(s);
      await t.pumpWidget(
        faMaterial(
          home: MeetingDetailScreen(env: e.env, meetingId: 'm1'),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
}
