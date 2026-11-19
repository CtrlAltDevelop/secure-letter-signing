import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/screens/biometric_enrol.dart';
import 'package:letter_signing/screens/sessions_tab.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart' show faMaterial;
import 'letters/fakes.dart';
import 'signing_pin_test.dart' show userJson;

const _title = 'استفاده از اثر انگشت / چهره در این دستگاه';

class EnrolHarness {
  EnrolHarness(this.auth, this.bio, this.patches);
  final AuthController auth;
  final FakeBiometrics bio;
  final List<Map<String, dynamic>> patches;
}

/// A restored, logged-in controller whose server answers PATCH with [patchStatus].
Future<EnrolHarness> harness({
  bool available = true,
  bool flagged = false,
  bool bioResult = true,
  int patchStatus = 200,
  String detail = 'Wrong signing PIN',
}) async {
  final patches = <Map<String, dynamic>>[];
  final f = fakeApi((req, body) {
    if (req.url.path == '/api/auth/refresh') {
      return json({'access': 'a2', 'refresh': 'r2'});
    }
    if (req.url.path == '/api/me/sessions/current') {
      patches.add(body as Map<String, dynamic>);
      if (patchStatus != 200) return json({'detail': detail}, patchStatus);
      return json(sessionJson('S1', current: true, biometric: true));
    }
    if (req.url.path == '/api/me/sessions') {
      return json([
        sessionJson('S1', current: true, biometric: flagged),
        sessionJson('S2', biometric: true),
      ]);
    }
    if (req.url.path == '/api/me') return json(userJson(hasPin: true));
    return json({});
  });
  final bio = FakeBiometrics(isAvailable: available, result: bioResult);
  final auth = AuthController(f.client, biometrics: bio);
  await auth.restore();
  return EnrolHarness(auth, bio, patches);
}

Future<void> pumpPrompt(WidgetTester t, AuthController auth) async {
  await useTallSurface(t);
  await t.pumpWidget(
    MaterialApp(
      home: BiometricEnrolPrompt(
        auth: auth,
        child: const Scaffold(body: Text('home')),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> enable(WidgetTester t, String pin) async {
  await t.enterText(find.byType(TextFormField), pin);
  await t.tap(find.text('فعال‌سازی'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('dialog validates six digits before doing anything', (t) async {
    final h = await harness();
    await pumpPrompt(t, h.auth);
    expect(find.text(_title), findsOneWidget);
    await enable(t, '123');
    expect(find.text('6 رقم وارد کنید'), findsOneWidget);
    expect(h.bio.reasons, isEmpty);
    expect(h.patches, isEmpty);
  });

  testWidgets('success authenticates, then patches with the pin', (t) async {
    final h = await harness();
    await pumpPrompt(t, h.auth);
    await enable(t, '123456');
    expect(h.bio.reasons, ['فعال‌سازی اثر انگشت / چهره در این دستگاه']);
    expect(h.patches, [
      {'biometric': true, 'pin': '123456'},
    ]);
    expect(find.text(_title), findsNothing);
    expect(h.auth.sessionBiometric, isTrue);
    expect(h.auth.needsBiometricEnrolment, isFalse);
  });

  testWidgets('a cancelled biometric check sends nothing', (t) async {
    final h = await harness(bioResult: false);
    await pumpPrompt(t, h.auth);
    await enable(t, '123456');
    expect(h.bio.reasons, hasLength(1));
    expect(h.patches, isEmpty);
    expect(find.text(_title), findsOneWidget);
  });

  testWidgets('wrong PIN shows the server text and keeps the dialog', (
    t,
  ) async {
    final h = await harness(patchStatus: 403);
    await pumpPrompt(t, h.auth);
    await enable(t, '000000');
    expect(find.text('Wrong signing PIN'), findsOneWidget);
    expect(find.text(_title), findsOneWidget);
    expect(h.auth.sessionBiometric, isFalse);
  });

  testWidgets('a locked account shows the server text', (t) async {
    final h = await harness(patchStatus: 429, detail: 'Too many attempts');
    await pumpPrompt(t, h.auth);
    await enable(t, '000000');
    expect(find.text('Too many attempts'), findsOneWidget);
    expect(find.text(_title), findsOneWidget);
  });

  testWidgets('Not now suppresses the dialog for the rest of the run', (
    t,
  ) async {
    final h = await harness();
    await pumpPrompt(t, h.auth);
    await t.tap(find.text('فعلاً نه'));
    await t.pumpAndSettle();
    expect(find.text(_title), findsNothing);
    expect(h.auth.needsBiometricEnrolment, isFalse);
    await pumpPrompt(t, h.auth);
    expect(find.text(_title), findsNothing);
  });

  testWidgets('no dialog when biometrics are unavailable or enrolled', (
    t,
  ) async {
    await pumpPrompt(t, (await harness(available: false)).auth);
    expect(find.text(_title), findsNothing);
    await pumpPrompt(t, (await harness(flagged: true)).auth);
    expect(find.text(_title), findsNothing);
  });

  group('error mapping', () {
    for (final status in [403, 409, 429]) {
      test('$status becomes a BiometricEnrolError', () async {
        final h = await harness(patchStatus: status, detail: 'nope');
        await expectLater(
          h.auth.enrollBiometric('123456'),
          throwsA(
            isA<BiometricEnrolError>()
                .having((e) => e.status, 'status', status)
                .having((e) => e.message, 'message', 'nope'),
          ),
        );
      });
    }
  });

  group('Devices tab button', () {
    Future<List<String>> pumpTab(
      WidgetTester t, {
      required bool available,
      required bool flagged,
    }) async {
      await useTallSurface(t);
      final h = await harness(available: available, flagged: flagged);
      await t.pumpWidget(
        faMaterial(
          home: Scaffold(body: SessionsTab(auth: h.auth)),
        ),
      );
      await t.pumpAndSettle();
      return [for (final p in h.patches) '$p'];
    }

    testWidgets('shown on the current row when available and not flagged', (
      t,
    ) async {
      await pumpTab(t, available: true, flagged: false);
      expect(find.text('فعال‌سازی اثر انگشت / چهره'), findsOneWidget);
    });

    testWidgets('hidden when flagged or unavailable', (t) async {
      await pumpTab(t, available: true, flagged: true);
      expect(find.text('فعال‌سازی اثر انگشت / چهره'), findsNothing);
      await pumpTab(t, available: false, flagged: false);
      expect(find.text('فعال‌سازی اثر انگشت / چهره'), findsNothing);
    });

    testWidgets('opens the dialog and refreshes after success', (t) async {
      final h = await harness();
      await useTallSurface(t);
      await t.pumpWidget(
        faMaterial(
          home: Scaffold(body: SessionsTab(auth: h.auth)),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('فعال‌سازی اثر انگشت / چهره'));
      await t.pumpAndSettle();
      expect(find.text(_title), findsOneWidget);
      await enable(t, '123456');
      expect(h.patches, hasLength(1));
      expect(find.text(_title), findsNothing);
    });
  });
}
