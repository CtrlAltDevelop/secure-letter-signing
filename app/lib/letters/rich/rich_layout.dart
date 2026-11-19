import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/letters/rich/rich_doc.dart';

/// A4 in logical points (72 per inch).
const double a4Width = 595;
const double a4Height = 842;
const double pageMargin = 54;
const double headerHeight = 112;
const double titleHeight = 72;
const double footerHeight = 36;
const double signatureHeight = 104;

/// Height of the strip that lists the paraphs (initials) under the signatures.
const double paraphHeight = 44;
const double bulletIndent = 22;

bool isListKind(ParaKind k) => k == ParaKind.bullet || k == ParaKind.numbered;

const List<Color?> _palette = [
  null,
  Color(0xFF165EF6),
  Color(0xFFB3261E),
  Color(0xFF1F8F78),
];
const double lineHeightFactor = 1.5;
const double contentWidth = a4Width - 2 * pageMargin;

/// True when the first letter with a strong direction is Arabic-script/Hebrew.
bool isRtlText(String s) {
  for (final r in s.runes) {
    if ((r >= 0x0590 && r <= 0x08FF) || (r >= 0xFB1D && r <= 0xFEFC)) {
      return true;
    }
    if ((r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A)) return false;
  }
  return false;
}

/// Direction of a paragraph: the explicit choice, else the first strong letter.
bool paraIsRtl(ParaStyle p, String text) => switch (p.dir) {
  ParaDir.ltr => false,
  ParaDir.rtl => true,
  ParaDir.auto => isRtlText(text),
};

double kindScale(ParaKind k) => switch (k) {
  ParaKind.h1 => 1.7,
  ParaKind.h2 => 1.35,
  _ => 1,
};

TextStyle _style(int flags, ParaKind kind, double font, TextStyle? base) =>
    (base ?? const TextStyle()).copyWith(
      color: _palette[colorIndex(flags)] ?? base?.color,
      fontSize:
          font *
          kindScale(kind) *
          (flags & flagLarge != 0 ? 1.35 : (flags & flagSmall != 0 ? 0.8 : 1)),
      height: lineHeightFactor,
      fontWeight:
          (flags & flagBold != 0 || kind == ParaKind.h1 || kind == ParaKind.h2)
          ? FontWeight.w700
          : null,
      fontStyle: flags & flagItalic != 0 ? FontStyle.italic : null,
      decoration: flags & flagUnderline != 0 ? TextDecoration.underline : null,
    );

/// Styled spans for [start, end) of the document text.
TextSpan richSpan(
  RichDoc doc,
  int start,
  int end,
  double font,
  TextStyle? base,
) {
  final children = <TextSpan>[];
  var para = doc.paraAt(start);
  var from = start;
  for (var i = start; i <= end; i++) {
    final atEnd = i == end;
    final changes =
        !atEnd &&
        i > from &&
        (doc.flags[i] != doc.flags[from] || doc.text.codeUnitAt(i - 1) == 10);
    if (atEnd || changes) {
      if (i > from) {
        children.add(
          TextSpan(
            text: doc.text.substring(from, i),
            style: _style(doc.flags[from], doc.paras[para].kind, font, base),
          ),
        );
      }
      if (!atEnd && doc.text.codeUnitAt(i - 1) == 10) para++;
      from = i;
    }
  }
  return TextSpan(children: children);
}

/// What the editor paints: the whole document with inline styles and heading sizes.
TextSpan editorSpan(RichDoc doc, double font, TextStyle? base) =>
    richSpan(doc, 0, doc.text.length, font, base);

/// A run of lines of one paragraph that lands on one page.
class PageSlice {
  const PageSlice(
    this.para,
    this.start,
    this.end, {
    required this.first,
    required this.last,
  });
  final int para;
  final int start;
  final int end;
  final bool first; // first line of the paragraph (draws the bullet)
  final bool last; // last line of the paragraph (adds the gap after)
}

double bodyCapacity({required bool first}) =>
    a4Height -
    2 * pageMargin -
    footerHeight -
    (first ? headerHeight + titleHeight : 0);

double _gap(double font) => font * 0.4;

/// Splits [doc] into A4 pages at line boundaries. Signature blocks sit under the last page's text; when they do
/// not fit they get a page of their own (an empty slice list).
List<List<PageSlice>> paginateRich(
  RichDoc doc,
  double font, {
  int signatureCount = 0,
  int paraphCount = 0,
}) {
  final pages = <List<PageSlice>>[[]];
  var used = 0.0;
  var capacity = bodyCapacity(first: true);
  void newPage() {
    pages.add([]);
    used = 0;
    capacity = bodyCapacity(first: false);
  }

  final starts = doc.paraStarts;
  for (var i = 0; i < doc.paras.length; i++) {
    final ps = starts[i];
    final pe = i + 1 < starts.length ? starts[i + 1] - 1 : doc.text.length;
    final kind = doc.paras[i].kind;
    if (ps == pe) {
      final h = font * kindScale(kind) * lineHeightFactor;
      if (used + h > capacity && pages.last.isNotEmpty) newPage();
      pages.last.add(PageSlice(i, ps, ps, first: true, last: true));
      used += h + _gap(font);
      continue;
    }
    final width = contentWidth - (isListKind(kind) ? bulletIndent : 0);
    final painter = TextPainter(
      text: richSpan(doc, ps, pe, font, null),
      textDirection: paraIsRtl(doc.paras[i], doc.text.substring(ps, pe))
          ? TextDirection.rtl
          : TextDirection.ltr,
    )..layout(maxWidth: width);
    final lines = painter.computeLineMetrics();
    var sliceStart = ps;
    var pendingLines = 0; // lines of this paragraph placed on the current page but not yet added as a slice
    for (var l = 0; l < lines.length; l++) {
      final m = lines[l];
      final y = m.baseline - m.ascent + m.height / 2;
      final b = painter.getLineBoundary(
        painter.getPositionForOffset(Offset(width / 2, y)),
      );
      if (used + m.height > capacity &&
          (pages.last.isNotEmpty || pendingLines > 0)) {
        if (sliceStart < ps + b.start) {
          pages.last.add(
            PageSlice(
              i,
              sliceStart,
              ps + b.start,
              first: sliceStart == ps,
              last: false,
            ),
          );
          sliceStart = ps + b.start;
        }
        newPage();
        pendingLines = 0;
      }
      used += m.height;
      pendingLines++;
      if (l == lines.length - 1) {
        pages.last.add(
          PageSlice(i, sliceStart, pe, first: sliceStart == ps, last: true),
        );
        used += _gap(font);
      }
    }
    painter.dispose();
  }
  final tail =
      signatureCount * signatureHeight + (paraphCount > 0 ? paraphHeight : 0);
  if (tail > 0 && used + tail > capacity) pages.add([]);
  return pages;
}

/// The body text of one A4 page: paragraphs with their alignment, bullets and direction.
class PaperBody extends StatelessWidget {
  const PaperBody({
    super.key,
    required this.doc,
    required this.slices,
    required this.font,
    required this.ink,
  });
  final RichDoc doc;
  final List<PageSlice> slices;
  final double font;
  final Color ink;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [for (final s in slices) _slice(s)],
  );

  /// 1-based position of paragraph [i] in its run of consecutive numbered paragraphs.
  int _number(int i) {
    var n = 1;
    while (i - n >= 0 && doc.paras[i - n].kind == ParaKind.numbered) {
      n++;
    }
    return n;
  }

  Widget _slice(PageSlice s) {
    final style = doc.paras[s.para];
    final gap = s.last ? _gap(font) : 0.0;
    if (s.start == s.end) {
      return SizedBox(
        height: font * kindScale(style.kind) * lineHeightFactor + gap,
      );
    }
    final rtl = paraIsRtl(style, doc.text.substring(s.start, s.end));
    final dir = rtl ? TextDirection.rtl : TextDirection.ltr;
    final text = Text.rich(
      richSpan(doc, s.start, s.end, font, TextStyle(color: ink)),
      textDirection: dir,
      textAlign: switch (style.align) {
        ParaAlign.start => TextAlign.start,
        ParaAlign.center => TextAlign.center,
        ParaAlign.end => TextAlign.end,
        ParaAlign.justify => TextAlign.justify,
      },
    );
    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Directionality(
        textDirection: dir,
        child: isListKind(style.kind)
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: bulletIndent,
                    child: s.first
                        ? Text(
                            style.kind == ParaKind.numbered
                                ? '${_number(s.para)}.'
                                : '•',
                            style: TextStyle(
                              color: ink,
                              fontSize: font,
                              height: lineHeightFactor,
                            ),
                          )
                        : null,
                  ),
                  Expanded(child: text),
                ],
              )
            : text,
      ),
    );
  }
}
