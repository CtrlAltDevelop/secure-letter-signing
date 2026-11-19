import 'dart:typed_data';

import 'package:material_ui/material_ui.dart' show Icons, ThemeMode, ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/prefs/notification_history_screen.dart';
import 'package:letter_signing/prefs/prefs_api.dart';
import 'package:letter_signing/prefs/prefs_controller.dart';
import 'package:letter_signing/prefs/settings_screen.dart';
import 'package:letter_signing/prefs/theme_mode.dart';
import 'package:letter_signing/workspace/file_pick.dart';
import 'package:letter_signing/workspace/open_target.dart';

import '../helpers.dart';
import '../letters/fakes.dart';
import 'ws_harness.dart';

Map<String, dynamic> _prefs({
  String theme = 'auto',
  String? dnd,
  String email = '',
  bool verified = false,
  bool bg = false,
}) => {
  'theme': theme,
  'birthday': null,
  'birthday_visible': true,
  'dnd_until': dnd,
  'personal_email': email,
  'personal_email_verified': verified,
  'has_background': bg,
};

Ws _server() {
  var current = _prefs();
  return ws((req, body) {
    final p = pathOf(req);
    if (p == '/me/prefs' && req.method == 'PATCH') {
      current = {...current, ...(body as Map).cast<String, dynamic>()};
      return json(current);
    }
    if (p == '/me/prefs') return json(current);
    if (p == '/me') return json({'status_text': 'busy'});
    if (p == '/me/personal-email') {
      current = _prefs(email: (body as Map)['email'] as String);
      return json({'detail': 'ok'});
    }
    if (p == '/me/personal-email/verify') {
      return (body as Map)['token'] == 'good'
          ? json(_prefs(email: 'a@b.c', verified: true))
          : json({'detail': 'bad'}, 400);
    }
    if (p == '/me/background' && req.method == 'POST')
      return json(_prefs(bg: true));
    if (p == '/me/notifications/read') return json({'detail': 'ok'});
    if (p == '/me/notifications') {
      return json([
        {
          'id': 1,
          'kind': 'mention',
          'title': 'old',
          'data': {},
          'at': '2026-03-01T10:00:00Z',
          'read': true,
        },
        {
          'id': 2,
          'kind': 'letter_published',
          'title': 'fresh',
          'data': {'letter_id': 'L1'},
          'at': '2026-03-02T10:00:00Z',
          'read': false,
        },
      ]);
    }
    if (p == '/me/mentions') {
      return json([
        {
          'comment_id': 9,
          'subject_id': 'S1',
          'module': 'tasks',
          'kind': 'task',
          'title': 'Fix it',
          'excerpt': 'hey @me',
          'author': {'id': 3, 'full_name': 'Sara', 'email': 's@x'},
          'report': false,
          'created_at': '2026-03-02T10:00:00Z',
        },
      ]);
    }
    return json(<Object>[]);
  });
}

void main() {
  tearDown(() => appThemeMode.value = ThemeMode.system);

  test('theme change is saved and applied app-wide', () async {
    final w = _server();
    final c = PrefsController(PrefsApi(w.api));
    await c.load();
    expect(await c.setTheme('dark'), isTrue);
    expect(appThemeMode.value, ThemeMode.dark);
    expect(c.statusText, 'busy');
    c.dispose();
  });

  test('clearing birthday and dnd sends explicit nulls', () async {
    final w = _server();
    final c = PrefsController(PrefsApi(w.api));
    await c.setBirthday(null);
    await c.setDnd(null);
    final bodies = w.where('PATCH', '/me/prefs').map((r) => r.body).toList();
    expect(bodies[0], contains('"birthday":null'));
    expect(bodies[1], contains('"dnd_until":null'));
    c.dispose();
  });

  testWidgets('settings: dark theme, dnd preset and status are sent', (
    t,
  ) async {
    await useTallSurface(t);
    final w = _server();
    final c = PrefsController(PrefsApi(w.api));
    final now = DateTime(2026, 3, 10, 12);
    await t.pumpWidget(
      faMaterial(
        home: SettingsScreen(
          controller: c,
          userTitle: 'Manager',
          open: (x, y) async {},
          now: () => now,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-title')), findsOneWidget);
    await t.tap(find.text('تیره'));
    await t.pumpAndSettle();
    expect(appThemeMode.value, ThemeMode.dark);
    await t.tap(find.byKey(const ValueKey('dnd-1')));
    await t.pumpAndSettle();
    final body = w.where('PATCH', '/me/prefs').last.body;
    expect(
      DateTime.parse(
        RegExp(r'"dnd_until":"([^"]+)"').firstMatch(body)!.group(1)!,
      ),
      now.add(const Duration(hours: 1)).toUtc(),
    );
    await t.enterText(find.byKey(const ValueKey('status-field')), 'away');
    await t.tap(find.byKey(const ValueKey('status-save')));
    await t.pumpAndSettle();
    expect(w.where('PATCH', '/me').last.body, contains('away'));
    c.dispose();
  });

  testWidgets('personal email: send then verify', (t) async {
    await useTallSurface(t);
    final w = _server();
    final c = PrefsController(PrefsApi(w.api));
    await t.pumpWidget(
      faMaterial(
        home: SettingsScreen(
          controller: c,
          userTitle: '',
          open: (x, y) async {},
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('pe-email')), 'a@b.c');
    await t.tap(find.byKey(const ValueKey('pe-send')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('pe-token')), 'good');
    await t.tap(find.byKey(const ValueKey('pe-verify')));
    await t.pumpAndSettle();
    expect(c.prefs.personalEmailVerified, isTrue);
    c.dispose();
  });

  testWidgets('background upload uses the picker', (t) async {
    final w = _server();
    final c = PrefsController(
      PrefsApi(w.api),
      pickFile: () async => PickedFile(
        name: 'b.png',
        bytes: Uint8List.fromList([1]),
        contentType: 'image/png',
      ),
    );
    expect(await c.chooseBackground(), isTrue);
    expect(w.where('POST', '/me/background'), hasLength(1));
    expect(c.prefs.hasBackground, isTrue);
    expect(appBackground.value, isNotNull);
    c.dispose();
    await t.pump();
    expect(appBackground.value, isNull);
  });

  testWidgets('notification history: unread filter, mark all, mentions', (
    t,
  ) async {
    await useTallSurface(t);
    final w = _server();
    final opened = <OpenTarget>[];
    await t.pumpWidget(
      faMaterial(
        home: NotificationHistoryScreen(
          api: PrefsApi(w.api),
          open: (c, x) async => opened.add(x),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('old'), findsOneWidget);
    await t.tap(find.text('خوانده‌نشده'));
    await t.pumpAndSettle();
    expect(find.text('old'), findsNothing);
    await t.tap(find.byKey(const ValueKey('mark-all-read')));
    await t.pumpAndSettle();
    expect(w.where('POST', '/me/notifications/read'), hasLength(1));
    expect(
      find.text('fresh'),
      findsNothing,
    ); // now read, hidden by the unread filter
    await t.tap(find.text('اشاره‌ها'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('mention-9')));
    expect(opened.single.subjectId, 'S1');
    expect(find.byIcon(Icons.alternate_email), findsWidgets);
  });
}
