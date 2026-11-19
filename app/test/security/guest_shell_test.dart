import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/screens/home_screen.dart';
import 'package:letter_signing/workspace/workspace_env.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import '../letters/fakes.dart';
import 'security_fixtures.dart';

Future<void> _pump(WidgetTester t, FakeSecurityServer server, auth, {double width = 400}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(width, 900);
  addTearDown(t.view.reset);
  await t.pumpWidget(faApp(HomeScreen(auth: auth, live: FakeLive(auth.api))));
  await t.pumpAndSettle();
  // The one-time fingerprint offer is not under test here.
  if (find.text('فعلاً نه').evaluate().isNotEmpty) {
    await t.tap(find.text('فعلاً نه'));
    await t.pumpAndSettle();
  }
}

void main() {
  test('a guest starts with only the guest modules until /me/modules answers', () async {
    final s = fakeSecurity()..server.guestMe = true;
    await s.auth.restore();
    final env = WorkspaceEnv.forAuth(s.auth, deviceName: 'x', live: FakeLive(s.auth.api));
    expect(env.enabledModules, unorderedEquals(guestModuleCodes));
  });

  testWidgets('a guest sees the expiry notice and only the modules the server returned', (t) async {
    final s = fakeSecurity()
      ..server.guestMe = true
      ..server.guestExpires = '2099-05-01T00:00:00Z';
    await s.auth.restore();
    await _pump(t, s.server, s.auth);

    expect(find.byKey(const ValueKey('account-banner')), findsOneWidget);
    expect(find.textContaining('تا ۱۴۷۸/'), findsOneWidget);
    expect(find.byKey(const ValueKey('open-search')), findsNothing);
    final labels = t
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label)
        .toList();
    expect(labels, ['وظایف', 'پروژه‌ها', 'گفتگو', 'بیشتر']);

    await t.tap(find.text('بیشتر'));
    await t.pumpAndSettle();
    expect(find.text('پروفایل'), findsOneWidget);
    expect(find.text('دستگاه‌ها'), findsOneWidget);
    for (final hidden in ['نامه‌ها', 'جلسات', 'برچسب‌ها', 'مدیریت', 'تقویم', 'همه نامه‌ها']) {
      expect(find.text(hidden), findsNothing, reason: hidden);
    }
  });

  testWidgets('an ordinary user sees no guest notice and keeps search', (t) async {
    final s = fakeSecurity();
    await s.auth.restore();
    await _pump(t, s.server, s.auth);
    expect(find.byKey(const ValueKey('account-banner')), findsNothing);
    expect(find.byKey(const ValueKey('open-search')), findsOneWidget);
  });
}
