import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/sign_approval_host.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import 'fakes.dart';

Future<void> pumpHost(WidgetTester t, LettersEnv env) async {
  await useTallSurface(t);
  await t.pumpWidget(
    faMaterial(
      home: SignApprovalHost(
        env: env,
        child: const Scaffold(body: Text('home')),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('shows an incoming request loaded on start', (t) async {
    final f = fakeApi(
      (req, _) => req.url.path == '/api/sign-requests/incoming'
          ? json([signRequestJson('R1', note: 'please')])
          : json({}),
    );
    await pumpHost(t, testEnv(f));
    expect(find.text('Budget'), findsOneWidget);
    expect(find.text('تصمیم: تأیید'), findsOneWidget);
    expect(find.textContaining('please'), findsOneWidget);
    expect(find.textContaining('laptop'), findsOneWidget);
  });

  testWidgets('approve runs the biometric check, then posts approve', (
    t,
  ) async {
    final f = fakeApi((req, _) {
      if (req.url.path == '/api/sign-requests/incoming') {
        return json([signRequestJson('R1')]);
      }
      return json(signRequestJson('R1', status: 'approved'));
    });
    final bio = FakeBiometrics();
    await pumpHost(t, testEnv(f, biometrics: bio));
    await t.tap(find.text('تأیید'));
    await t.pumpAndSettle();
    expect(bio.reasons.single, contains('Budget'));
    expect(
      f.calls.any(
        (c) =>
            c.method == 'POST' && c.url.path == '/api/sign-requests/R1/approve',
      ),
      isTrue,
    );
    expect(find.text('تأیید امضا؟'), findsNothing);
  });

  testWidgets('a failed biometric check posts nothing and keeps the dialog', (
    t,
  ) async {
    final f = fakeApi(
      (req, _) => req.url.path == '/api/sign-requests/incoming'
          ? json([signRequestJson('R1')])
          : json({}),
    );
    await pumpHost(t, testEnv(f, biometrics: FakeBiometrics(result: false)));
    await t.tap(find.text('تأیید'));
    await t.pumpAndSettle();
    expect(f.calls.where((c) => c.url.path.endsWith('/approve')), isEmpty);
    expect(find.text('تأیید امضا؟'), findsOneWidget);
  });

  testWidgets('decline posts decline without biometrics', (t) async {
    final f = fakeApi((req, _) {
      if (req.url.path == '/api/sign-requests/incoming') {
        return json([signRequestJson('R1')]);
      }
      return json(signRequestJson('R1', status: 'declined'));
    });
    final bio = FakeBiometrics();
    await pumpHost(t, testEnv(f, biometrics: bio));
    await t.tap(find.text('رد درخواست'));
    await t.pumpAndSettle();
    expect(bio.reasons, isEmpty);
    expect(
      f.calls.any((c) => c.url.path == '/api/sign-requests/R1/decline'),
      isTrue,
    );
    expect(find.text('تأیید امضا؟'), findsNothing);
  });

  testWidgets('a live sign_request frame opens the dialog', (t) async {
    final f = fakeApi((req, _) => json(<dynamic>[]));
    final live = FakeLive(f.client);
    await pumpHost(t, testEnv(f, live: live));
    expect(find.text('تأیید امضا؟'), findsNothing);
    live.push({'type': 'sign_request', 'request': signRequestJson('R9')});
    await t.pumpAndSettle();
    expect(find.text('تأیید امضا؟'), findsOneWidget);
  });

  testWidgets('the dialog closes when the request is cancelled elsewhere', (
    t,
  ) async {
    final f = fakeApi(
      (req, _) => req.url.path == '/api/sign-requests/incoming'
          ? json([signRequestJson('R1')])
          : json({}),
    );
    final live = FakeLive(f.client);
    await pumpHost(t, testEnv(f, live: live));
    live.push({
      'type': 'sign_request_update',
      'request': signRequestJson('R1', status: 'cancelled'),
    });
    await t.pumpAndSettle();
    expect(find.text('تأیید امضا؟'), findsNothing);
  });
}
