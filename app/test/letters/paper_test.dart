import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/letters/letterhead.dart';
import 'package:letter_signing/letters/paper_editor_screen.dart';
import 'package:letter_signing/letters/paper_pages.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('paginate splits long text into pages without losing words', () {
    final text = List.generate(300, (i) => 'line number $i').join('\n');
    final pages = paginate(text, 12, rtl: false);
    expect(pages.length, greaterThan(1));
    expect(pages.join('\n').split('\n'), text.split('\n'));
  });

  test('bigger font needs more pages', () {
    final text = List.generate(120, (i) => 'line number $i').join('\n');
    expect(
      paginate(text, 18, rtl: false).length,
      greaterThan(paginate(text, 9, rtl: false).length),
    );
  });

  test('rtl text is detected and paginated', () {
    final text = List.generate(200, (i) => 'سلام دنیا $i').join('\n');
    expect(isRtlText(text), isTrue);
    expect(paginate(text, 12, rtl: true).join('\n'), text);
  });

  testWidgets('letterhead header shows name; footer falls back to contact line', (t) async {
    const head = Letterhead(name: 'Acme', phone: '123', website: 'a.test');
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LetterheadHeader(head: head)),
      ),
    );
    expect(find.text('Acme'), findsOneWidget);
    expect(head.footerText, '123  |  a.test');
  });

  testWidgets('paper editor returns the typed text on Done', (t) async {
    String? result;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () async => result = await Navigator.of(c).push<String>(
              MaterialPageRoute(
                builder: (_) => const PaperEditorScreen(
                  head: Letterhead(name: 'Acme'),
                  title: 'T',
                  initialText: 'old',
                ),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    expect(find.text('Acme'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'new text');
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    expect(result, 'new text');
  });
}
