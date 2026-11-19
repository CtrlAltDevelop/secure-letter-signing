import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/letters/sign_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import 'fakes.dart';

const me = FakeUser(2, 'me@x.test');

LetterDetail letter() => LetterDetail.fromJson(
  detailJson(
    briefJson('L1', status: 'in_signing', title: 'Budget'),
    participants: [participantJson(me)],
  ),
);

List<Map<String, dynamic>> sessions({bool biometric = false}) => [
  sessionJson('S1', device: 'laptop', current: true, biometric: biometric),
  sessionJson('S2', device: 'phone', biometric: true),
];

Future<void> open(
  WidgetTester t,
  LettersEnv env, {
  Duration timeout = const Duration(minutes: 5),
}) async {
  await useTallSurface(t);
  await t.pumpWidget(
    faMaterial(
      home: SignScreen(
        env: env,
        letter: letter(),
        approvalTimeout: timeout,
        pollEvery: const Duration(seconds: 3),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Finder pinField() => find.widgetWithText(TextFormField, 'رمز امضا');

void main() {
  layoutTests();
  testWidgets('PIN path posts decision, note and pin', (t) async {
    Map<String, dynamic>? posted;
    final f = fakeApi((req, body) {
      if (req.url.path == '/api/me/sessions') return json(sessions());
      if (req.url.path == '/api/letters/L1/sign') {
        posted = body as Map<String, dynamic>;
        return json(briefJson('L1', status: 'published'));
      }
      return json({});
    });
    await open(t, testEnv(f));
    await t.tap(find.text('رد'));
    await t.enterText(find.widgetWithText(TextField, 'یادداشت (اختیاری)'), 'no');
    await t.enterText(pinField(), '123456');
    await t.tap(find.text('امضا با رمز'));
    await t.pumpAndSettle();
    expect(posted, {'decision': 'rejected', 'note': 'no', 'pin': '123456'});
  });

  testWidgets('PIN path rejects a short PIN without a request', (t) async {
    final f = fakeApi(
      (req, _) => json(req.url.path == '/api/me/sessions' ? sessions() : {}),
    );
    await open(t, testEnv(f));
    await t.enterText(pinField(), '123');
    await t.tap(find.text('امضا با رمز'));
    await t.pumpAndSettle();
    expect(find.text('۶ رقم وارد کنید'), findsOneWidget);
    expect(f.calls.where((c) => c.url.path.endsWith('/sign')), isEmpty);
  });

  testWidgets('wrong PIN shows the server message and stays open', (t) async {
    final f = fakeApi((req, _) {
      if (req.url.path == '/api/letters/L1/sign') {
        return json({'detail': 'Wrong signing PIN'}, 403);
      }
      return json(sessions());
    });
    await open(t, testEnv(f));
    await t.enterText(pinField(), '000000');
    await t.tap(find.text('امضا با رمز'));
    await t.pumpAndSettle();
    expect(find.text('Wrong signing PIN'), findsOneWidget);
    expect(find.byType(SignScreen), findsOneWidget);
  });

  testWidgets('no biometric button on a non-biometric session', (t) async {
    final f = fakeApi((req, _) => json(sessions()));
    await open(t, testEnv(f));
    expect(find.text('اثر انگشت / چهره'), findsNothing);
  });

  testWidgets('enable link appears when available but not enrolled', (t) async {
    final f = fakeApi((req, _) => json(sessions()));
    await open(t, testEnv(f, enrollBiometric: (_) async => true));
    expect(find.text('فعال‌سازی اثر انگشت / چهره'), findsOneWidget);
    expect(find.text('اثر انگشت / چهره'), findsNothing);
    expect(find.text('تأیید با phone من'), findsOneWidget);
  });

  testWidgets('enable link is hidden when enrolled or unavailable', (t) async {
    final enrolled = fakeApi((req, _) => json(sessions(biometric: true)));
    await open(t, testEnv(enrolled, enrollBiometric: (_) async => true));
    expect(find.text('فعال‌سازی اثر انگشت / چهره'), findsNothing);
    final none = fakeApi((req, _) => json(sessions()));
    await open(
      t,
      testEnv(
        none,
        biometrics: FakeBiometrics(isAvailable: false),
        enrollBiometric: (_) async => true,
      ),
    );
    expect(find.text('فعال‌سازی اثر انگشت / چهره'), findsNothing);
  });

  testWidgets('enable link opens the dialog', (t) async {
    final pins = <String>[];
    final f = fakeApi((req, _) => json(sessions()));
    await open(
      t,
      testEnv(
        f,
        enrollBiometric: (pin) async {
          pins.add(pin);
          return true;
        },
      ),
    );
    await t.tap(find.text('فعال‌سازی اثر انگشت / چهره'));
    await t.pumpAndSettle();
    expect(find.text('Use fingerprint / face on this device'), findsOneWidget);
    await t.enterText(
      find.widgetWithText(TextFormField, 'Signing PIN').last,
      '123456',
    );
    await t.tap(find.text('Enable'));
    await t.pumpAndSettle();
    expect(pins, ['123456']);
  });

  testWidgets('biometric path posts after local auth succeeded', (t) async {
    Map<String, dynamic>? posted;
    final f = fakeApi((req, body) {
      if (req.url.path == '/api/me/sessions') {
        return json(sessions(biometric: true));
      }
      if (req.url.path == '/api/letters/L1/sign-biometric') {
        posted = body as Map<String, dynamic>;
        return json(briefJson('L1', status: 'published'));
      }
      return json({});
    });
    final bio = FakeBiometrics();
    await open(t, testEnv(f, biometrics: bio));
    await t.tap(find.text('اثر انگشت / چهره'));
    await t.pumpAndSettle();
    expect(bio.reasons.single, contains('Budget'));
    expect(posted, {'decision': 'approved', 'note': ''});
  });

  testWidgets('nothing is posted when local auth fails', (t) async {
    final f = fakeApi((req, _) => json(sessions(biometric: true)));
    await open(t, testEnv(f, biometrics: FakeBiometrics(result: false)));
    await t.tap(find.text('اثر انگشت / چهره'));
    await t.pumpAndSettle();
    expect(find.text('تأیید اثر انگشت یا چهره ناموفق بود'), findsOneWidget);
    expect(f.calls.where((c) => c.url.path.contains('sign')), isEmpty);
  });

  testWidgets('Ask my phone completes on an approved update frame', (t) async {
    Map<String, dynamic>? posted;
    final f = fakeApi((req, body) {
      if (req.url.path == '/api/me/sessions') return json(sessions());
      if (req.url.path == '/api/letters/L1/sign-requests') {
        posted = body as Map<String, dynamic>;
        return json(signRequestJson('R1'), 201);
      }
      if (req.url.path == '/api/letters/L1') {
        return json(detailJson(briefJson('L1', status: 'published')));
      }
      return json(signRequestJson('R1'));
    });
    final live = FakeLive(f.client);
    final env = testEnv(f, live: live);
    LetterBrief? result;
    await useTallSurface(t);
    await t.pumpWidget(
      faMaterial(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await Navigator.of(context)
                .push<LetterBrief>(
                  MaterialPageRoute(
                    builder: (_) => SignScreen(env: env, letter: letter()),
                  ),
                ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    await t.tap(find.text('تأیید با phone من'));
    await t.pump();
    await t.pump();
    expect(posted, {
      'decision': 'approved',
      'note': '',
      'approver_session_id': 'S2',
    });
    expect(find.text('در انتظار تأیید روی phone'), findsOneWidget);

    live.push({
      'type': 'sign_request_update',
      'request': signRequestJson('R1', status: 'approved'),
    });
    await t.pumpAndSettle();
    expect(result?.status, 'published');
    expect(find.byType(SignScreen), findsNothing);
  });

  testWidgets('Cancel stops waiting and calls cancel', (t) async {
    final f = fakeApi((req, _) {
      if (req.url.path == '/api/me/sessions') return json(sessions());
      return json(signRequestJson('R1'));
    });
    await open(t, testEnv(f));
    await t.tap(find.text('تأیید با phone من'));
    await t.pump();
    await t.pump();
    await t.tap(find.text('انصراف'));
    await t.pumpAndSettle();
    expect(
      f.calls.any((c) => c.url.path == '/api/sign-requests/R1/cancel'),
      isTrue,
    );
    expect(find.text('امضا با رمز'), findsOneWidget);
  });

  testWidgets('a declined update returns to the PIN with a message', (t) async {
    final f = fakeApi((req, _) {
      if (req.url.path == '/api/me/sessions') return json(sessions());
      return json(signRequestJson('R1'));
    });
    final live = FakeLive(f.client);
    await open(t, testEnv(f, live: live));
    await t.tap(find.text('تأیید با phone من'));
    await t.pump();
    await t.pump();
    live.push({
      'type': 'sign_request_update',
      'request': signRequestJson('R1', status: 'declined'),
    });
    await t.pumpAndSettle();
    expect(find.textContaining('phone رد کرد'), findsOneWidget);
    expect(find.text('امضا با رمز'), findsOneWidget);
  });

  testWidgets('polling picks up a decision without a live frame', (t) async {
    var polls = 0;
    final f = fakeApi((req, _) {
      if (req.url.path == '/api/me/sessions') return json(sessions());
      if (req.url.path == '/api/letters/L1/sign-requests') {
        return json(signRequestJson('R1'), 201);
      }
      if (req.url.path == '/api/sign-requests/R1') {
        polls++;
        return json(signRequestJson('R1', status: 'expired'));
      }
      return json({});
    });
    await open(t, testEnv(f));
    await t.tap(find.text('تأیید با phone من'));
    await t.pump();
    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();
    expect(polls, greaterThan(0));
    expect(find.textContaining('منقضی'), findsOneWidget);
  });

  testWidgets('the timeout falls back to the PIN', (t) async {
    final f = fakeApi((req, _) {
      if (req.url.path == '/api/me/sessions') return json(sessions());
      if (req.url.path == '/api/letters/L1/sign-requests') {
        return json(signRequestJson('R1'), 201);
      }
      return json(signRequestJson('R1'));
    });
    await open(t, testEnv(f), timeout: const Duration(seconds: 10));
    await t.tap(find.text('تأیید با phone من'));
    await t.pump();
    await t.pump(const Duration(seconds: 11));
    await t.pumpAndSettle();
    expect(find.textContaining('phone پاسخ نداد'), findsOneWidget);
    expect(find.text('امضا با رمز'), findsOneWidget);
    expect(f.calls.any((c) => c.url.path.endsWith('/cancel')), isTrue);
  });
}

void layoutTests() {
  for (final size in const [Size(375, 812), Size(844, 390)]) {
    testWidgets('sign screen fits ${size.width}x${size.height}', (t) async {
      await useTallSurface(t, size);
      final f = fakeApi((req, _) => json(sessions(biometric: true)));
      await t.pumpWidget(
        faMaterial(
          home: SignScreen(env: testEnv(f), letter: letter()),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('تأیید با phone من', skipOffstage: false), findsOneWidget);
    });
  }
}
