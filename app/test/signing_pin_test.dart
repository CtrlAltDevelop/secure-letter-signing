import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/screens/signing_pin.dart';
import 'package:letter_signing/screens/ui_bits.dart';
import 'package:material_ui/material_ui.dart';

import 'letters/fakes.dart';

Map<String, dynamic> userJson({bool hasPin = false}) => {
  'id': 2,
  'email': 'me@x.test',
  'full_name': 'Me',
  'title': '',
  'department': '',
  'department_id': null,
  'is_manager': false,
  'is_active': true,
  'has_signing_pin': hasPin,
  'permissions': ['letter.sign'],
};

void main() {
  test('pin validation needs exactly six digits', () {
    expect(isValidPin('123456'), isTrue);
    expect(isValidPin('12345'), isFalse);
    expect(isValidPin('1234567'), isFalse);
    expect(isValidPin('12a456'), isFalse);
  });

  testWidgets('gate validates digits, match and password, then saves', (
    t,
  ) async {
    await useTallSurface(t);
    Map<String, dynamic>? put;
    final f = fakeApi((req, body) {
      if (req.method == 'PUT' && req.url.path == '/api/me/signing-pin') {
        put = body as Map<String, dynamic>;
        return json({'detail': 'ok'});
      }
      return json({});
    });
    final auth = AuthController(f.client, biometrics: FakeBiometrics());
    await t.pumpWidget(MaterialApp(home: SigningPinGate(auth: auth)));
    final fields = find.byType(TextFormField);

    await t.tap(find.text('Save PIN'));
    await t.pumpAndSettle();
    expect(find.text('Enter 6 digits'), findsWidgets);
    expect(find.text('Enter your login password'), findsOneWidget);
    expect(put, isNull);

    await t.enterText(fields.at(0), '123456');
    await t.enterText(fields.at(1), '654321');
    await t.enterText(fields.at(2), 'secret-pass');
    await t.tap(find.text('Save PIN'));
    await t.pumpAndSettle();
    expect(find.text('The PINs do not match'), findsOneWidget);
    expect(put, isNull);

    await t.enterText(fields.at(1), '123456');
    await t.tap(find.text('Save PIN'));
    await t.pumpAndSettle();
    expect(put, {'pin': '123456', 'password': 'secret-pass'});
  });

  test('login ignores biometrics for the session flag', () async {
    Map<String, dynamic>? sent;
    final f = fakeApi((req, body) {
      if (req.url.path == '/api/auth/login') {
        sent = body as Map<String, dynamic>;
        return json({
          'access': 'a',
          'refresh': 'r',
          'session_id': 'S1',
          'user': userJson(),
        });
      }
      return json({});
    });
    final auth = AuthController(f.client, biometrics: FakeBiometrics());
    await auth.login('me@x.test', 'pw', deviceName: 'phone', platform: 'ios');
    expect(sent?.containsKey('biometric'), isFalse);
    expect(auth.user?.hasSigningPin, isFalse);
    expect(auth.sessionBiometric, isFalse);
    expect(auth.needsBiometricEnrolment, isTrue);
  });

  Future<(AuthController, List<String>)> restored({
    required bool available,
    required bool flagged,
  }) async {
    final patches = <String>[];
    final f = fakeApi((req, body) {
      if (req.url.path == '/api/auth/refresh') {
        return json({'access': 'a2', 'refresh': 'r2'});
      }
      if (req.url.path == '/api/me/sessions/current') {
        patches.add('${req.method} ${jsonEncode(body)}');
        return json(sessionJson('S7', current: true));
      }
      if (req.url.path == '/api/me/sessions') {
        return json([
          sessionJson('S7', current: true, biometric: flagged),
          sessionJson('S8', biometric: true),
        ]);
      }
      if (req.url.path == '/api/me') return json(userJson(hasPin: true));
      return json({});
    });
    final auth = AuthController(
      f.client,
      biometrics: FakeBiometrics(isAvailable: available),
    );
    await auth.restore();
    return (auth, patches);
  }

  test('restore: unavailable and flagged clears the flag', () async {
    final (auth, patches) = await restored(available: false, flagged: true);
    expect(patches, ['PATCH {"biometric":false}']);
    expect(auth.sessionId, 'S7');
    expect(auth.sessionBiometric, isFalse);
    expect(auth.needsBiometricEnrolment, isFalse);
    expect(auth.user?.hasSigningPin, isTrue);
  });

  test('restore: available and flagged does nothing', () async {
    final (auth, patches) = await restored(available: true, flagged: true);
    expect(patches, isEmpty);
    expect(auth.sessionBiometric, isTrue);
    expect(auth.needsBiometricEnrolment, isFalse);
  });

  test('restore: available and not flagged asks for enrolment', () async {
    final (auth, patches) = await restored(available: true, flagged: false);
    expect(patches, isEmpty);
    expect(auth.needsBiometricEnrolment, isTrue);
    expect(auth.canEnrollBiometric, isTrue);
    auth.dismissBiometricEnrolment();
    expect(auth.needsBiometricEnrolment, isFalse);
    expect(auth.canEnrollBiometric, isTrue);
  });

  test('restore survives a failing session patch', () async {
    final f = fakeApi((req, _) {
      if (req.url.path == '/api/auth/refresh') {
        return json({'access': 'a2', 'refresh': 'r2'});
      }
      if (req.url.path == '/api/me') return json(userJson(hasPin: true));
      return json({'detail': 'down'}, 500);
    });
    final auth = AuthController(f.client, biometrics: FakeBiometrics());
    await auth.restore();
    expect(auth.user, isNotNull);
  });

  test('models parse the v3 json', () {
    final req = SignRequest.fromJson(signRequestJson('R1'));
    expect(req.isPending, isTrue);
    expect(req.requesterDeviceName, 'laptop');
    final sig = SignatureInfo.fromJson(
      signatureJson(const FakeUser(2, 'a@b.c')),
    );
    expect(sig.method, 'pin');
    expect(sig.seal, 'c2VhbA==');
    expect(sig.contentHash, hasLength(64));
    final s = SessionInfo.fromJson(sessionJson('S1', biometric: true));
    expect(s.biometric, isTrue);
    expect(s.displayName, 'phone');
    final d = LetterDetail.fromJson(
      detailJson(briefJson('L1'), body: {'text': 'x'}),
    );
    expect(d.body['text'], 'x');
    final live = LiveEvent({
      'type': 'sign_request',
      'request': signRequestJson('R2'),
    });
    expect(live.isSignRequest, isTrue);
    expect(live.eventId, isNull);
    expect(live.request?.id, 'R2');
    expect(LiveEvent({'type': 'letter'}).request, isNull);
  });
}
