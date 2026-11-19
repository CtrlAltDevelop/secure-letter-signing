import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/letters/secretariat_detail_screen.dart';
import 'package:letter_signing/letters/secretariat_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import 'fakes.dart';
import 'letters_v2_fixtures.dart';

void main() {
  testWidgets('list filters by direction and registers a new entry', (t) async {
    final s = FakeLettersServer();
    s.entries.add(entryJson('e0', title: 'Old', party: 'Ministry'));
    await useTallSurface(t, const Size(375, 812));
    await t.pumpWidget(
      faMaterial(home: SecretariatScreen(env: v2Env(s, secretariat: true))),
    );
    await t.pumpAndSettle();
    expect(find.text('Old'), findsOneWidget);
    expect(find.text('۱۴۰۵/۰۰۰۱'), findsOneWidget);

    await t.tap(find.text('صادره'));
    await t.pumpAndSettle();
    expect(
      s.calls
          .lastWhere((c) => c.url.path.endsWith('/entries'))
          .url
          .queryParameters['direction'],
      'out',
    );

    await t.tap(find.text('ثبت نامه'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'عنوان'), 'Reply');
    await t.enterText(find.widgetWithText(TextField, 'نام فرستنده'), 'Acme');
    await t.pump();
    await t.tap(find.widgetWithText(FilledButton, 'ذخیره'));
    await t.pumpAndSettle();
    final body = s.lastBody('POST', '/secretariat/entries') as Map;
    expect(body['direction'], 'in');
    expect(body['title'], 'Reply');
    expect(body['party_name'], 'Acme');
  });

  testWidgets('register needs a title and outgoing offers a letter', (t) async {
    final s = FakeLettersServer();
    await useTallSurface(t, const Size(375, 812));
    await t.pumpWidget(
      faMaterial(home: SecretariatScreen(env: v2Env(s, secretariat: true))),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('ثبت نامه'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'ذخیره'));
    await t.pumpAndSettle();
    expect(find.text('عنوان را وارد کنید'), findsOneWidget);
    expect(s.where('POST', '/secretariat'), isEmpty);

    expect(find.text('انتخاب نامه موجود (اختیاری)'), findsNothing);
    await t.tap(find.text('صادره').last);
    await t.pumpAndSettle();
    expect(find.text('انتخاب نامه موجود (اختیاری)'), findsOneWidget);
  });

  testWidgets('detail edits the entry and uploads a file', (t) async {
    final s = FakeLettersServer();
    final entry = SecretariatEntry.fromJson(entryJson('e1', title: 'Before'));
    s.entries.add(entryJson('e1', title: 'Before'));
    final env = v2Env(s, secretariat: true);
    await useTallSurface(t, const Size(375, 1200));
    await t.pumpWidget(
      faMaterial(
        home: SecretariatDetailScreen(env: env, entry: entry),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Before'), findsOneWidget);
    expect(find.text('پرونده‌ای پیوست نشده است'), findsNothing);

    await t.tap(find.byTooltip('ویرایش'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'عنوان'), 'After');
    await t.pump();
    await t.tap(find.widgetWithText(FilledButton, 'ذخیره'));
    await t.pumpAndSettle();
    expect(
      (s.lastBody('PATCH', '/secretariat/entries/e1') as Map)['title'],
      'After',
    );
    expect(find.text('After'), findsOneWidget);
  });

  for (final size in const [Size(375, 812), Size(844, 390)]) {
    testWidgets('secretariat list fits ${size.width}x${size.height}', (
      t,
    ) async {
      final s = FakeLettersServer();
      s.entries.add(
        entryJson(
          'e0',
          title: 'A long entry title for the register',
          party: 'Some very long ministry name',
        ),
      );
      await useTallSurface(t, size);
      await t.pumpWidget(
        faMaterial(home: SecretariatScreen(env: v2Env(s, secretariat: true))),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
}
