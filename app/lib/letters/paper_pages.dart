import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/letters/letterhead.dart';

/// A4 in logical points (72 per inch).
const double a4Width = 595;
const double a4Height = 842;
const double pageMargin = 54;
const double _headerHeight = 96;
const double _titleHeight = 62;
const double _footerHeight = 36;
const Color _ink = Color(0xFF111827);

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

/// Splits [text] into per-page strings at line boundaries for an A4 page at [fontSize].
/// The first page has less room (header + title block).
List<String> paginate(String text, double fontSize, {required bool rtl}) {
  const contentWidth = a4Width - 2 * pageMargin;
  final painter = TextPainter(
    text: TextSpan(text: text, style: bodyStyle(fontSize)),
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
  )..layout(maxWidth: contentWidth);
  final lines = painter.computeLineMetrics();
  final pages = <String>[];
  var start = 0;
  var used = 0.0;
  var capacity = _bodyCapacity(first: true);
  var pageStart = 0;
  for (var i = 0; i < lines.length; i++) {
    final m = lines[i];
    final top = m.baseline - m.ascent;
    final y = top + m.height / 2;
    final b = painter.getLineBoundary(
      painter.getPositionForOffset(Offset(contentWidth / 2, y)),
    );
    if (used + m.height > capacity && i > 0) {
      pages.add(text.substring(pageStart, start).trimRight());
      pageStart = b.start;
      used = 0;
      capacity = _bodyCapacity(first: false);
    }
    start = b.end;
    used += m.height;
  }
  pages.add(text.substring(pageStart).trimRight());
  painter.dispose();
  return pages;
}

double _bodyCapacity({required bool first}) =>
    a4Height -
    2 * pageMargin -
    _footerHeight -
    (first ? _headerHeight + _titleHeight : 0);

TextStyle bodyStyle(double fontSize) =>
    TextStyle(color: _ink, fontSize: fontSize, height: 1.5);

/// One A4 sheet. Wrap in a RepaintBoundary to rasterize for printing.
class PaperPage extends StatelessWidget {
  const PaperPage({
    super.key,
    required this.head,
    required this.index,
    required this.count,
    required this.text,
    required this.fontSize,
    required this.rtl,
    required this.title,
    required this.subtitle,
  });
  final Letterhead head;
  final int index;
  final int count;
  final String text;
  final double fontSize;
  final bool rtl;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final dir = rtl ? TextDirection.rtl : TextDirection.ltr;
    return Container(
      width: a4Width,
      height: a4Height,
      color: Colors.white,
      padding: const EdgeInsets.all(pageMargin),
      child: DefaultTextStyle(
        style: const TextStyle(color: _ink),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (index == 0) ...[
              SizedBox(
                height: _headerHeight,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: LetterheadHeader(head: head, ink: _ink),
                ),
              ),
              SizedBox(
                height: _titleHeight,
                child: Directionality(
                  textDirection: dir,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 10, color: _ink),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            Expanded(
              child: Directionality(
                textDirection: dir,
                child: Text(text, style: bodyStyle(fontSize)),
              ),
            ),
            SizedBox(
              height: _footerHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Divider(height: 1, color: _ink),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          head.footer,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 9, color: _ink),
                        ),
                      ),
                      Text(
                        '${index + 1} / $count',
                        style: const TextStyle(fontSize: 9, color: _ink),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
