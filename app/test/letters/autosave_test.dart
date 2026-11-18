import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/letters/create_letter_screen.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/live_service.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes.dart';

void main() {
  final me = FakeUser(1, 'me@x.test');
  final signer = FakeUser(2, 's@x.test');

  testWidgets(
    'autosaves an encrypted draft once title and signer are set, then stays quiet',
    (t) async {
      t.view.devicePixelRatio = 1;
      await t.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() {
        t.view.resetDevicePixelRatio();
        t.binding.setSurfaceSize(null);
      });
      final f = fakeApi((req, _) {
        if (req.url.path == '/api/keys/directory') {
          return json([me.directoryJson, signer.directoryJson]);
        }
        if (req.url.path == '/api/letters' && req.method == 'POST') {
          return json(briefJson('L1', status: 'draft'));
        }
        return json(briefJson('L1', status: 'draft'));
      });
      final env = LettersEnv(
        api: f.api,
        vault: FakeVault(me.unlocked),
        companyKeys: FakeCompanyKeys(),
        live: LiveService(api: f.client, cursor: MemoryCursorStore()),
        userId: me.id,
      );
      List<String> saves() => [
        for (final c in f.calls)
          if (c.url.path.startsWith('/api/letters') && c.method != 'GET')
            '${c.method} ${c.url.path}',
      ];

      await t.pumpWidget(
        MaterialApp(
          home: CreateLetterScreen(
            env: env,
            autosaveEvery: const Duration(milliseconds: 200),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.pump(const Duration(milliseconds: 500));
      expect(saves(), isEmpty); // nothing to save yet

      await t.enterText(find.widgetWithText(TextField, 'Title'), 'Budget');
      await t.tap(find.text('Choose signers'));
      await t.pumpAndSettle();
      await t.tap(find.byType(CheckboxListTile).first);
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      expect(saves(), ['POST /api/letters']);
      expect(find.textContaining('auto-saved'), findsOneWidget);

      await t.pump(
        const Duration(milliseconds: 600),
      ); // unchanged: no second save
      expect(saves(), hasLength(1));
      await t.enterText(find.widgetWithText(TextField, 'Title'), 'Budget 2');
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      expect(saves().last, startsWith('PUT'));
      await t.pumpWidget(const SizedBox()); // dispose cancels the timer
    },
  );
}
