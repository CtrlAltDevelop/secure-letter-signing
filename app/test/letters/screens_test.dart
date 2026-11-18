import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/letters/letter_detail_screen.dart';
import 'package:letter_signing/letters/letter_service.dart';
import 'package:letter_signing/letters/letters_list_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes.dart';

void main() {
  const me = FakeUser(2, 'me@x.test');

  testWidgets(
    'list nests chained letters under their parent and filters by status',
    (tester) async {
      final f = fakeApi((req, _) {
        if (req.url.path == '/api/letters') {
          return json([
            briefJson(
              'c1',
              no: 3,
              parentId: 'p1',
              title: 'Child',
              status: 'rejected',
            ),
            briefJson('p1', no: 1, title: 'Parent', status: 'published'),
            briefJson('o1', no: 2, title: 'Other', status: 'in_signing'),
          ]);
        }
        if (req.url.path == '/api/me/notifications') return json([]);
        return json({});
      });
      await tester.pumpWidget(
        MaterialApp(home: LettersListScreen(env: testEnv(f))),
      );
      await tester.pumpAndSettle();

      double y(String t) => tester.getTopLeft(find.text(t)).dy;
      expect(find.text('Other'), findsOneWidget);
      expect(y('Parent') < y('Child'), isTrue);
      expect(
        tester.getTopLeft(find.text('Child')).dx,
        greaterThan(tester.getTopLeft(find.text('Parent')).dx),
      );

      await tester.tap(find.widgetWithText(FilterChip, 'In signing'));
      await tester.pumpAndSettle();
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('Parent'), findsNothing);
    },
  );

  testWidgets('list shows a server error', (tester) async {
    final f = fakeApi((req, _) => json({'detail': 'boom'}, 500));
    await tester.pumpWidget(
      MaterialApp(home: LettersListScreen(env: testEnv(f))),
    );
    await tester.pumpAndSettle();
    expect(find.text('boom'), findsOneWidget);
  });

  testWidgets('detail shows the plain body, method and device', (tester) async {
    await useTallSurface(tester);
    final f = fakeApi((req, _) {
      if (req.url.path == '/api/letters/L1') {
        return json(
          detailJson(
            briefJson('L1', status: 'published', title: 'Budget'),
            body: {'text': 'Pay the invoice', 'attachments': []},
            participants: [participantJson(me, decision: 'approved')],
            signatures: [
              signatureJson(me, method: 'biometric', device: 'phone'),
            ],
          ),
        );
      }
      return json({});
    });
    await tester.pumpWidget(
      MaterialApp(
        home: LetterDetailScreen(env: testEnv(f), letterId: 'L1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Pay the invoice'), findsOneWidget);
    expect(find.textContaining('phone'), findsOneWidget);
    expect(find.textContaining('Biometric'), findsWidgets);
  });

  test('attachment limits are enforced before any request', () async {
    final f = fakeApi((_, _) => json({}));
    final svc = LetterService(api: f.api, userId: 1);
    final bad = DraftInput(
      title: 't',
      text: '',
      signerIds: [2],
      attachments: [
        PendingAttachment(
          name: 'a.exe',
          type: 'application/x-msdownload',
          bytes: Uint8List.fromList([1]),
        ),
      ],
    );
    await expectLater(svc.saveDraft(bad), throwsA(isA<LetterException>()));
    expect(f.calls, isEmpty);
  });

  test(
    'a draft goes up as a plain body, attachments as plain uploads',
    () async {
      final f = fakeApi((req, body) {
        if (req.url.path == '/api/letters') return json(briefJson('L1'));
        return json({
          'id': 'A1',
          'content_type': 'application/pdf',
          'label': '0',
          'size': 1,
        }, 201);
      });
      final svc = LetterService(api: f.api, userId: 1);
      await svc.saveDraft(
        DraftInput(
          title: ' t ',
          text: 'hello',
          signerIds: [2],
          attachments: [
            PendingAttachment(
              name: 'a.pdf',
              type: 'application/pdf',
              bytes: Uint8List.fromList([1]),
            ),
          ],
        ),
      );
      expect(f.calls.map((c) => '${c.method} ${c.url.path}'), [
        'POST /api/letters',
        'POST /api/letters/L1/attachments',
      ]);
      expect(f.calls.first.body, contains('"text":"hello"'));
      expect(f.calls.first.body, isNot(contains('"wraps"')));
      expect(f.calls.last.body, isNot(contains('iv')));
    },
  );
}
