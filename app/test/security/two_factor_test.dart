import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/screens/profile_tab.dart';
import 'package:letter_signing/screens/sessions_tab.dart';
import 'package:letter_signing/security/login_history_screen.dart';
import 'package:letter_signing/security/two_factor_login_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import '../letters/fakes.dart';
import 'security_fixtures.dart';

final _dialogField = find
    .descendant(of: find.byType(AlertDialog), matching: find.byType(TextField))
    .first;

void main() {
  test(
    'login with 2FA stops at the challenge, then the code opens the session',
    () async {
      final s = fakeSecurity();
      final done = await s.auth.login('me@x.test', 'pw');
      expect(done, isFalse);
      expect(s.auth.user, isNull);
      expect(s.auth.twoFactorChallenge, 'CH1');

      await s.auth.completeTwoFactor('123456', deviceName: 'macos');
      expect(s.auth.user?.email, 'me@x.test');
      expect(s.auth.twoFactorChallenge, isNull);
      expect(s.server.lastBody('POST', '/auth/login/2fa'), {
        'challenge': 'CH1',
        'code': '123456',
        'device_name': 'macos',
        'platform': '',
      });
    },
  );

  test('a recovery code is sent as recovery_code, not code', () async {
    final s = fakeSecurity();
    await s.auth.login('me@x.test', 'pw');
    await s.auth.completeTwoFactor('abcd-efgh', recovery: true);
    final body = s.server.lastBody('POST', '/auth/login/2fa')! as Map;
    expect(body['recovery_code'], 'abcd-efgh');
    expect(body.containsKey('code'), isFalse);
  });

  test('a wrong code is an ApiException and keeps the challenge', () async {
    final s = fakeSecurity();
    await s.auth.login('me@x.test', 'pw');
    await expectLater(
      s.auth.completeTwoFactor('000000'),
      throwsA(isA<ApiException>()),
    );
    expect(s.auth.user, isNull);
    expect(s.auth.twoFactorChallenge, 'CH1');
  });

  testWidgets(
    'code screen validates six digits, shows the server error, then signs in',
    (t) async {
      await useTallSurface(t);
      final s = fakeSecurity();
      await s.auth.login('me@x.test', 'pw');
      await t.pumpWidget(faMaterial(home: TwoFactorLoginScreen(auth: s.auth)));

      await t.enterText(find.byKey(const ValueKey('two-factor-code')), '12');
      await t.tap(find.text('ادامه'));
      await t.pumpAndSettle();
      expect(find.text('کد باید ۶ رقم باشد'), findsOneWidget);

      await t.enterText(
        find.byKey(const ValueKey('two-factor-code')),
        '000000',
      );
      await t.tap(find.text('ادامه'));
      await t.pumpAndSettle();
      expect(find.text('The code is wrong'), findsOneWidget);
      expect(s.auth.user, isNull);

      await t.enterText(
        find.byKey(const ValueKey('two-factor-code')),
        '123456',
      );
      await t.tap(find.text('ادامه'));
      await t.pumpAndSettle();
      expect(s.auth.user, isNotNull);
    },
  );

  testWidgets('the code screen can switch to a recovery code', (t) async {
    await useTallSurface(t);
    final s = fakeSecurity();
    await s.auth.login('me@x.test', 'pw');
    await t.pumpWidget(faMaterial(home: TwoFactorLoginScreen(auth: s.auth)));
    await t.tap(find.byKey(const ValueKey('two-factor-toggle')));
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const ValueKey('two-factor-code')),
      'abcd-1234',
    );
    await t.tap(find.text('ادامه'));
    await t.pumpAndSettle();
    expect(
      (s.server.lastBody('POST', '/auth/login/2fa')! as Map)['recovery_code'],
      'abcd-1234',
    );
  });

  testWidgets(
    'enabling 2FA shows the secret, confirms a code and shows the 10 recovery codes once',
    (t) async {
      await useTallSurface(t);
      final s = fakeSecurity();
      await s.auth.restore();
      await t.pumpWidget(
        faMaterial(
          home: Scaffold(
            body: ProfileTab(auth: s.auth, securityApi: s.api),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('غیرفعال'), findsOneWidget);

      await t.ensureVisible(find.byKey(const ValueKey('two-factor-enable')));
      await t.tap(find.byKey(const ValueKey('two-factor-enable')));
      await t.pumpAndSettle();
      expect(find.text('JBSWY3DPEHPK3PXP'), findsOneWidget);
      expect(find.textContaining('otpauth://totp'), findsOneWidget);

      await t.enterText(
        find.byKey(const ValueKey('two-factor-confirm-code')),
        '12',
      );
      await t.tap(find.byKey(const ValueKey('two-factor-confirm')));
      await t.pumpAndSettle();
      expect(find.text('کد باید ۶ رقم باشد'), findsOneWidget);

      await t.enterText(
        find.byKey(const ValueKey('two-factor-confirm-code')),
        '654321',
      );
      await t.tap(find.byKey(const ValueKey('two-factor-confirm')));
      await t.pumpAndSettle();
      expect(s.server.lastBody('POST', '/2fa/confirm'), {'code': '654321'});
      expect(find.text('کدهای بازیابی'), findsOneWidget);
      for (var i = 0; i < 10; i++) {
        expect(find.text('rc-code-$i'), findsOneWidget);
      }
      await t.tap(find.byKey(const ValueKey('recovery-done')));
      await t.pumpAndSettle();
      expect(find.text('rc-code-0'), findsNothing);
      expect(find.text('فعال'), findsOneWidget);
      expect(find.text('کدهای بازیابی باقی‌مانده: 10'), findsOneWidget);
    },
  );

  testWidgets(
    'regenerating codes and disabling both send the password and a code',
    (t) async {
      await useTallSurface(t);
      final s = fakeSecurity();
      s.server.twoFactor = {
        'enabled': true,
        'setup_pending': false,
        'recovery_codes_left': 4,
        'required': false,
      };
      await s.auth.restore();
      await t.pumpWidget(
        faMaterial(
          home: Scaffold(
            body: ProfileTab(auth: s.auth, securityApi: s.api),
          ),
        ),
      );
      await t.pumpAndSettle();

      await t.ensureVisible(
        find.byKey(const ValueKey('two-factor-regenerate')),
      );
      await t.tap(find.byKey(const ValueKey('two-factor-regenerate')));
      await t.pumpAndSettle();
      // Both fields are required.
      await t.tap(find.byKey(const ValueKey('proof-submit')));
      await t.pumpAndSettle();
      expect(find.text('رمز عبور و کد را وارد کنید'), findsOneWidget);
      await t.enterText(_dialogField, 'hunter2');
      await t.enterText(find.byKey(const ValueKey('proof-code')), '111222');
      await t.tap(find.byKey(const ValueKey('proof-submit')));
      await t.pumpAndSettle();
      expect(s.server.lastBody('POST', '/2fa/recovery-codes'), {
        'password': 'hunter2',
        'code': '111222',
      });
      expect(find.text('new-code-3'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('recovery-done')));
      await t.pumpAndSettle();

      await t.ensureVisible(find.byKey(const ValueKey('two-factor-disable')));
      await t.tap(find.byKey(const ValueKey('two-factor-disable')));
      await t.pumpAndSettle();
      await t.tap(find.text('استفاده از کد بازیابی'));
      await t.pumpAndSettle();
      await t.enterText(_dialogField, 'hunter2');
      await t.enterText(find.byKey(const ValueKey('proof-code')), 'rec-77');
      await t.tap(find.byKey(const ValueKey('proof-submit')));
      await t.pumpAndSettle();
      expect(s.server.lastBody('POST', '/2fa/disable'), {
        'password': 'hunter2',
        'recovery_code': 'rec-77',
      });
      expect(find.byKey(const ValueKey('two-factor-enable')), findsOneWidget);
    },
  );

  testWidgets(
    'login history lists successes and failures with reason, IP and Jalali time',
    (t) async {
      await useTallSurface(t);
      final s = fakeSecurity();
      await t.pumpWidget(
        faMaterial(home: LoginHistoryScreen(load: s.api.myLoginHistory)),
      );
      await t.pumpAndSettle();
      expect(find.text('ورود موفق'), findsOneWidget);
      expect(find.text('ورود ناموفق: رمز عبور اشتباه'), findsOneWidget);
      expect(find.textContaining('1.2.3.4'), findsOneWidget);
      expect(find.textContaining('۱۴۰۵/'), findsWidgets);
    },
  );

  testWidgets('devices tab closes all other sessions after confirmation', (
    t,
  ) async {
    await useTallSurface(t);
    final s = fakeSecurity();
    await t.pumpWidget(
      faMaterial(
        home: Scaffold(body: SessionsTab(auth: s.auth)),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('close-other-sessions')));
    await t.pumpAndSettle();
    expect(s.server.called('POST', 'revoke-others'), isFalse);
    await t.tap(find.byKey(const ValueKey('close-others-confirm')));
    await t.pumpAndSettle();
    expect(s.server.called('POST', 'revoke-others'), isTrue);
  });
}
