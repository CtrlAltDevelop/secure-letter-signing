import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/crypto/document_crypto.dart';
import 'package:letter_signing/letters/letter_crypto_service.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/letters_list_screen.dart';
import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/letters/sign_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes.dart';

LettersEnv envFor(
  ({dynamic client, dynamic api, dynamic calls}) f,
  FakeUser me, {
  String? session = 'S1',
}) => LettersEnv(
  api: f.api,
  vault: FakeVault(me.unlocked),
  companyKeys: FakeCompanyKeys(),
  live: LiveService(api: f.client, cursor: MemoryCursorStore()),
  userId: me.id,
  deviceName: 'phone',
  sessionId: () => session,
);

void main() {
  final me = FakeUser(2, 'me@x.test');

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
        MaterialApp(home: LettersListScreen(env: envFor(f, me))),
      );
      await tester.pumpAndSettle();

      double y(String t) => tester.getTopLeft(find.text(t)).dy;
      expect(find.text('#2  Other'), findsOneWidget);
      expect(y('#1  Parent') < y('#3  Child'), isTrue);
      expect(
        tester.getTopLeft(find.text('#3  Child')).dx,
        greaterThan(tester.getTopLeft(find.text('#1  Parent')).dx),
      );

      await tester.tap(find.widgetWithText(FilterChip, 'In signing'));
      await tester.pumpAndSettle();
      expect(find.text('#2  Other'), findsOneWidget);
      expect(find.text('#1  Parent'), findsNothing);
    },
  );

  testWidgets('list shows a server error', (tester) async {
    final f = fakeApi((req, _) => json({'detail': 'boom'}, 500));
    await tester.pumpWidget(
      MaterialApp(home: LettersListScreen(env: envFor(f, me))),
    );
    await tester.pumpAndSettle();
    expect(find.text('boom'), findsOneWidget);
  });

  LetterDetail detail() {
    final docKey = newDocKey();
    return LetterDetail.fromJson(
      detailJson(
        briefJson('L1', status: 'in_signing', parentId: 'P', title: 'Budget'),
        body: encryptJson({'text': 'x', 'attachments': []}, docKey),
        participants: [participantJson(me)],
      ),
    );
  }

  testWidgets(
    'sign flow unlocks, signs exactly the server payload and submits',
    (tester) async {
      Map<String, dynamic>? posted;
      final f = fakeApi((req, body) {
        if (req.url.path == '/api/letters/L1/sign') {
          posted = body as Map<String, dynamic>;
          return json(briefJson('L1', status: 'published'));
        }
        return json({});
      });
      final env = envFor(f, me);
      final letter = detail();
      LetterBrief? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await Navigator.of(context)
                  .push<LetterBrief>(
                    MaterialPageRoute(
                      builder: (_) => SignScreen(env: env, letter: letter),
                    ),
                  ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'looks good');
      await tester.tap(find.text('Unlock key and sign'));
      await tester.pumpAndSettle();

      expect((env.vault as FakeVault).reasons.single, contains('Budget'));
      final payload = posted!['payload'] as Map<String, dynamic>;
      expect(payload['decision'], 'approved');
      expect(payload['note'], 'looks good');
      expect(payload['parentId'], 'P');
      expect(payload['sessionId'], 'S1');
      expect(payload['contentHash'], hasLength(64));
      expect(posted!['key_id'], me.keyId);
      expect(
        verifyPayload(
          payload,
          posted!['signature'] as String,
          me.identity.publicFile['sign'] as Map<String, dynamic>,
        ),
        isTrue,
      );
      expect(result?.status, 'published');
    },
  );

  testWidgets('sign shows server errors and stays open', (tester) async {
    final f = fakeApi(
      (req, _) => json({'detail': 'It is not your turn yet'}, 409),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SignScreen(env: envFor(f, me), letter: detail()),
      ),
    );
    await tester.tap(find.text('Reject'));
    await tester.pump();
    await tester.tap(find.text('Unlock key and sign'));
    await tester.pumpAndSettle();
    expect(find.text('It is not your turn yet'), findsOneWidget);
    expect(find.byType(SignScreen), findsOneWidget);
  });

  testWidgets('sign aborts when the unlock is cancelled', (tester) async {
    final f = fakeApi((req, _) => json({}));
    final env = envFor(f, me);
    (env.vault as FakeVault).key = null;
    await tester.pumpWidget(
      MaterialApp(
        home: SignScreen(env: env, letter: detail()),
      ),
    );
    await tester.tap(find.text('Unlock key and sign'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not unlocked'), findsOneWidget);
    expect(f.calls.where((c) => c.url.path.endsWith('/sign')), isEmpty);
  });

  test('attachment limits are enforced before any request', () async {
    final f = fakeApi((_, _) => json({}));
    final svc = LetterCryptoService(
      api: f.api,
      companyKeys: FakeCompanyKeys(),
      userId: 1,
    );
    final bad = DraftInput(
      title: 't',
      text: '',
      signerIds: [2],
      attachments: [
        PendingAttachment(
          name: 'a.exe',
          type: 'application/x-msdownload',
          bytes: utf8.encode('x') as dynamic,
        ),
      ],
    );
    await expectLater(svc.saveDraft(bad), throwsA(isA<LetterException>()));
    expect(f.calls, isEmpty);
  });
}
