import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/screens/auth_screens.dart';
import 'package:letter_signing/screens/ui_bits.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('helpers', () {
    test('validateEmail rejects bad shapes and accepts good ones', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('nope'), isNotNull);
      expect(validateEmail(' a@b.co '), isNull);
    });

    test('validateNewPassword enforces the minimum length', () {
      expect(validateNewPassword('short'), isNotNull);
      expect(validateNewPassword('longenough'), isNull);
    });

    test('initialsOf uses name, falls back to email', () {
      expect(initialsOf('Mona Lisa Smith', 'x@y.z'), 'ML');
      expect(initialsOf('', 'zed@y.z'), 'Z');
    });

    test('relativeTime formats recent and old times', () {
      final now = DateTime.utc(2026, 1, 10, 12);
      expect(relativeTime('2026-01-10T11:59:40Z', now: now), 'just now');
      expect(relativeTime('2026-01-10T11:30:00Z', now: now), '30 min ago');
      expect(relativeTime('2026-01-10T09:00:00Z', now: now), '3 h ago');
      expect(relativeTime('2026-01-08T12:00:00Z', now: now), '2 d ago');
    });
  });

  testWidgets('login shows inline validation and does not submit', (
    tester,
  ) async {
    final auth = AuthController(
      ApiClient(baseUrl: 'http://x.test', store: MemoryTokenStore()),
    );
    await tester.pumpWidget(MaterialApp(home: LoginScreen(auth: auth)));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Enter a valid email address'), findsNothing);
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });
}
