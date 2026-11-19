import '../helpers.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/letters/letter_service.dart';
import 'package:letter_signing/letters/letterhead.dart';
import 'package:letter_signing/letters/paper_editor_screen.dart';
import 'package:letter_signing/letters/rich/rich_controller.dart';
import 'package:letter_signing/letters/rich/rich_doc.dart';
import 'package:letter_signing/letters/rich/rich_layout.dart';
import 'package:material_ui/material_ui.dart';

String pageText(RichDoc d, List<PageSlice> page) =>
    page.map((s) => d.text.substring(s.start, s.end)).join('\n');

void main() {
  group('RichDoc', () {
    test('typed text takes the given flags and keeps the rest', () {
      final d = RichDoc.plain('ab').toggleFlag(0, 2, flagBold);
      final e = d.afterEdit('aXb', 0);
      expect(e.flags, [flagBold, 0, flagBold]);
    });

    test(
      'a split line copies the paragraph style, removing the break merges',
      () {
        final d = RichDoc('one', const [], const [
          ParaStyle(ParaKind.h1, ParaAlign.center),
        ]);
        final split = d.afterEdit('on\ne', 0);
        expect(split.paras, hasLength(2));
        expect(split.paras[1], const ParaStyle(ParaKind.h1, ParaAlign.center));
        expect(split.afterEdit('one', 0).paras, hasLength(1));
      },
    );

    test('explicit direction overrides the text and survives json', () {
      expect(paraIsRtl(const ParaStyle(), 'سلام'), isTrue);
      expect(
        paraIsRtl(
          const ParaStyle(ParaKind.normal, ParaAlign.start, ParaDir.ltr),
          'سلام',
        ),
        isFalse,
      );
      expect(
        paraIsRtl(
          const ParaStyle(ParaKind.normal, ParaAlign.start, ParaDir.rtl),
          'hello',
        ),
        isTrue,
      );
      final d = RichDoc('hello', const [], const [
        ParaStyle(ParaKind.normal, ParaAlign.start, ParaDir.rtl),
      ]);
      final back = RichDoc.fromJson('hello', d.toJson());
      expect(back.paras.single.dir, ParaDir.rtl);
    });

    test('whole-letter direction reaches every paragraph and new lines', () {
      final c = RichController(RichDoc.plain('a\nb'));
      c.setDirAll(ParaDir.rtl);
      expect(c.doc.paras.map((p) => p.dir), everyElement(ParaDir.rtl));
    });

    test('toggle clears when everything already has the flag', () {
      final d = RichDoc.plain('abc').toggleFlag(0, 3, flagItalic);
      expect(d.toggleFlag(0, 3, flagItalic).hasFormatting, isFalse);
    });

    test('json round trip, and mismatched data falls back to plain text', () {
      final d = RichDoc.plain('hi\nyo')
          .toggleFlag(0, 2, flagBold)
          .mapParas(3, 3, (p) => p.copyWith(kind: ParaKind.bullet));
      final back = RichDoc.fromJson('hi\nyo', d.toJson());
      expect(back.flags, d.flags);
      expect(back.paras, d.paras);
      expect(
        RichDoc.fromJson('different length', d.toJson()).hasFormatting,
        isFalse,
      );
      expect(RichDoc.fromJson('x', null).text, 'x');
    });

    test('body json keeps formatting inside the encrypted body', () {
      final rich = RichDoc.plain('hi').toggleFlag(0, 2, flagBold).toJson();
      final body = LetterService.bodyJson('hi', const [], rich: rich);
      expect(body['rich'], rich);
      expect(
        LetterService.bodyJson('hi', const []).containsKey('rich'),
        isFalse,
      );
    });
  });

  group('size, colour and numbered lists', () {
    test('setBits replaces only its own bits', () {
      final d = RichDoc.plain('abc')
          .toggleFlag(0, 3, flagBold)
          .setBits(0, 3, maskColor, 2 << colorShift)
          .setBits(0, 3, maskSize, flagLarge);
      expect(d.flags.first & flagBold, flagBold);
      expect(colorIndex(d.flags.first), 2);
      expect(d.flags.first & flagLarge, flagLarge);
      final cleared = d.setBits(0, 3, maskSize, 0);
      expect(cleared.flags.first & maskSize, 0);
      expect(colorIndex(cleared.flags.first), 2);
    });

    test('numbered kind survives json and old kinds keep their index', () {
      final d = RichDoc.plain('a\nb')
          .mapParas(0, 3, (p) => p.copyWith(kind: ParaKind.numbered));
      expect(
        RichDoc.fromJson('a\nb', d.toJson()).paras.first.kind,
        ParaKind.numbered,
      );
      expect(ParaKind.bullet.index, 3);
    });

    testWidgets(
      'numbered paragraphs are counted 1., 2. and restart after a break',
      (t) async {
        final d = RichDoc.plain('a\nb\nc\nd')
            .mapParas(0, 7, (p) => p.copyWith(kind: ParaKind.numbered));
        final broken = d
            .mapParas(4, 4, (p) => p.copyWith(kind: ParaKind.normal))
            .mapParas(6, 6, (p) => p.copyWith(kind: ParaKind.numbered));
        final slices = paginateRich(broken, 12).first;
        await t.pumpWidget(
          faMaterial(
            home: Scaffold(
              body: PaperBody(
                doc: broken,
                slices: slices,
                font: 12,
                ink: const Color(0xFF000000),
              ),
            ),
          ),
        );
        expect(find.text('1.'), findsNWidgets(2));
        expect(find.text('2.'), findsOneWidget);
      },
    );
  });

  group('RichController', () {
    test('toggle on a selection styles it and undo/redo restore it', () {
      final c = RichController(RichDoc.plain('hello'));
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      c.toggle(flagBold);
      expect(c.doc.flags, everyElement(flagBold));
      c.undo();
      expect(c.doc.hasFormatting, isFalse);
      c.redo();
      expect(c.doc.flags, everyElement(flagBold));
    });

    test('typing after a pinned toggle uses that style', () {
      final c = RichController(RichDoc.plain(''));
      c.toggle(flagItalic);
      c.value = const TextEditingValue(
        text: 'a',
        selection: TextSelection.collapsed(offset: 1),
      );
      expect(c.doc.flags, [flagItalic]);
    });
  });

  group('paginateRich', () {
    test('splits long text into pages without losing lines', () {
      final text = List.generate(300, (i) => 'line number $i').join('\n');
      final d = RichDoc.plain(text);
      final pages = paginateRich(d, 12);
      expect(pages.length, greaterThan(1));
      expect(
        pages.map((p) => pageText(d, p)).join('\n').split('\n'),
        text.split('\n'),
      );
    });

    test('bigger font needs more pages; headings take more room', () {
      final d = RichDoc.plain(List.generate(120, (i) => 'line $i').join('\n'));
      expect(
        paginateRich(d, 18).length,
        greaterThan(paginateRich(d, 9).length),
      );
      final h = d.mapParas(
        0,
        d.text.length,
        (p) => p.copyWith(kind: ParaKind.h1),
      );
      expect(
        paginateRich(h, 12).length,
        greaterThan(paginateRich(d, 12).length),
      );
    });

    test('right-to-left text paginates', () {
      final text = List.generate(200, (i) => 'سلام دنیا $i').join('\n');
      expect(isRtlText(text), isTrue);
      final d = RichDoc.plain(text);
      expect(paginateRich(d, 12).map((p) => pageText(d, p)).join('\n'), text);
    });

    test('long paragraph is split at line boundaries across pages', () {
      final d = RichDoc.plain(List.filled(900, 'word').join(' '));
      final pages = paginateRich(d, 12);
      expect(pages.length, greaterThan(1));
      final joined = pages
          .expand((p) => p)
          .map((s) => d.text.substring(s.start, s.end))
          .join();
      expect(joined.replaceAll(' ', ''), d.text.replaceAll(' ', ''));
    });

    test(
      'signature blocks move to their own page only when they do not fit',
      () {
        expect(
          paginateRich(RichDoc.plain('short'), 12, signatureCount: 1),
          hasLength(1),
        );
        final long = RichDoc.plain(
          List.generate(52, (i) => 'line $i').join('\n'),
        );
        final base = paginateRich(long, 12).length;
        expect(
          paginateRich(long, 12, signatureCount: 6).length,
          greaterThanOrEqualTo(base),
        );
      },
    );
  });

  testWidgets(
    'letterhead header shows name; footer falls back to contact line',
    (t) async {
      const head = Letterhead(name: 'Acme', phone: '123', website: 'a.test');
      await t.pumpWidget(
        faMaterial(
          home: Scaffold(body: LetterheadHeader(head: head)),
        ),
      );
      expect(find.text('Acme'), findsOneWidget);
      expect(head.footerText, '123  |  a.test');
    },
  );

  testWidgets(
    'editor: toolbar formats the selection, preview shows it, Done returns the document',
    (t) async {
      RichDoc? result;
      await t.pumpWidget(
        faMaterial(
          home: Builder(
            builder: (c) => TextButton(
              onPressed: () async =>
                  result = await Navigator.of(c).push<RichDoc>(
                    MaterialPageRoute(
                      builder: (_) => PaperEditorScreen(
                        head: const Letterhead(name: 'Acme'),
                        title: 'T',
                        initial: RichDoc.plain('old'),
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
      await t.enterText(find.byType(TextField), 'new text');
      await t.pump();
      final field = t.widget<EditableText>(find.byType(EditableText));
      field.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 3,
      );
      await t.tap(find.byTooltip('پررنگ'));
      await t.pump();
      expect(find.textContaining('2 کلمه'), findsOneWidget);
      await t.tap(find.text('پیش‌نمایش'));
      await t.pumpAndSettle();
      expect(find.text('Acme'), findsOneWidget);
      expect(find.text('موضوع: T'), findsOneWidget);
      await t.tap(find.text('ویرایش'));
      await t.pumpAndSettle();
      await t.tap(find.text('انجام شد'));
      await t.pumpAndSettle();
      expect(result!.text, 'new text');
      expect(result!.flags.take(3), everyElement(flagBold));
      expect(result!.flags.skip(3), everyElement(0));
    },
  );
}
