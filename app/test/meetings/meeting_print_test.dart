import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letterhead.dart';
import 'package:letter_signing/meetings/meeting_print.dart';
import 'package:letter_signing/meetings/models.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import '../letters/fakes.dart';
import '../tasks/task_fixtures.dart';
import 'meeting_fixtures.dart';

MeetingOut _meeting({String description = 'Minutes body'}) =>
    MeetingOut.fromJson(
      meetingFull(
        'm1',
        status: 'closed',
        description: description,
        attendees: [
          attendeeJson(1, role: 'chair', attendance: 'present'),
          attendeeJson(2, user: bob, role: 'member', attendance: 'absent'),
        ],
        resolutions: [
          resolutionJson(
            1,
            'Ship the release',
            owners: [3],
            due: '2026-06-01T00:00:00Z',
            status: 'done',
          ),
        ],
        signatures: [meetingSignature(1)],
      ),
    );

Future<void> _pump(WidgetTester t, MeetingOut m, Size size) async {
  await useTallSurface(t, size);
  await t.pumpWidget(
    faMaterial(
      home: MeetingPrintScreen(
        meeting: m,
        head: const Letterhead(name: 'Acme'),
        directory: const [UserRef(id: 3, fullName: 'Bob')],
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  test('paginateBlocks fills pages in order and never drops a block', () {
    final blocks = [
      for (var i = 0; i < 10; i++) PrintBlock(100, const SizedBox()),
    ];
    final pages = paginateBlocks(blocks, firstCapacity: 350, capacity: 450);
    expect(pages.map((p) => p.length), [3, 4, 3]);
    expect(pages.expand((p) => p), hasLength(10));
    final tall = paginateBlocks(
      [PrintBlock(900, const SizedBox())],
      firstCapacity: 300,
      capacity: 300,
    );
    expect(tall, hasLength(1));
  });

  test('splitLines breaks long text into several lines', () {
    final lines = splitLines(
      'word ' * 80,
      const TextStyle(fontSize: 12),
      200,
      TextDirection.ltr,
    );
    expect(lines.length, greaterThan(3));
    expect(
      lines.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim(),
      contains('word word'),
    );
  });

  testWidgets(
    'prints title, Jalali date, attendance, resolutions and signatures',
    (t) async {
      await _pump(t, _meeting(), const Size(900, 1300));
      expect(find.text('Weekly sync'), findsWidgets);
      expect(find.textContaining('۲۳۷۸'), findsWidgets);
      expect(find.text('Minutes body'), findsOneWidget);
      expect(find.text('حاضر'), findsOneWidget);
      expect(find.text('غایب'), findsOneWidget);
      expect(find.textContaining('Ship the release'), findsOneWidget);
      expect(find.textContaining('مسئولان: Bob'), findsOneWidget);
      expect(find.textContaining('سررسید'), findsOneWidget);
      expect(find.textContaining('Me: تأیید شد'), findsOneWidget);
      expect(find.text('Acme'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('long minutes flow onto more pages', (t) async {
    await _pump(
      t,
      _meeting(description: 'A long line of minutes. ' * 400),
      const Size(900, 1300),
    );
    final context = t.element(find.byType(MeetingPrintScreen));
    expect(AppLocalizations.of(context).meetingPrintTitle, 'صورتجلسه');
    expect(find.textContaining('۲ / '), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  for (final size in const [Size(375, 812), Size(844, 390)]) {
    testWidgets('print preview fits ${size.width}x${size.height}', (t) async {
      await _pump(t, _meeting(), size);
      expect(t.takeException(), isNull);
      expect(find.byTooltip('چاپ / ذخیره PDF'), findsOneWidget);
    });
  }
}
