import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/letters/letterhead.dart';

/// A4 in logical points (72 per inch).
const double a4Width = 595;
const double a4Height = 842;
const double pageMargin = 54;
const double _headerHeight = 112;
const double _titleHeight = 72;
const double signatureHeight = 104; // per signature block
const double _footerHeight = 36;
const Color _ink = paperInk;

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
List<String> paginate(
  String text,
  double fontSize, {
  required bool rtl,
  int signatureCount = 0,
}) {
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
  // The signature blocks sit under the text of the last page; if they do not fit, they get their own page.
  if (signatureCount > 0 &&
      used + signatureCount * signatureHeight > capacity) {
    pages.add('');
  }
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
    required this.number,
    required this.date,
    this.signatures = const [],
  });
  final Letterhead head;
  final int index;
  final int count;
  final String text;
  final double fontSize;
  final bool rtl;
  final String title;
  final String number;
  final String date;
  final List<PaperSignature> signatures;

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
                  child: LetterheadHeader(head: head),
                ),
              ),
              SizedBox(
                height: _titleHeight,
                child: Directionality(
                  textDirection: dir,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'No: $number',
                            style: const TextStyle(fontSize: 12, color: _ink),
                          ),
                          Text(
                            'Date: $date',
                            style: const TextStyle(fontSize: 12, color: _ink),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Subject: $title',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
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
            if (index == count - 1)
              for (final sig in signatures) SignatureBlock(sig: sig),
            SizedBox(
              height: _footerHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Divider(height: 1, color: paperGold),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          head.footerText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: paperMid),
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

/// One signer's decision, printed under the letter (like the original HTML letters).
class PaperSignature {
  const PaperSignature({
    required this.decision,
    required this.note,
    required this.name,
    required this.date,
    required this.fingerprint,
    required this.documentId,
  });
  final String decision; // approved | rejected
  final String note;
  final String name;
  final String date;
  final String fingerprint;
  final String documentId;
}

class SignatureBlock extends StatelessWidget {
  const SignatureBlock({super.key, required this.sig});
  final PaperSignature sig;

  @override
  Widget build(BuildContext context) {
    final approved = sig.decision == 'approved';
    final color = approved ? const Color(0xFF1F8F78) : const Color(0xFFD65959);
    const small = TextStyle(fontSize: 9, color: paperMid);
    return SizedBox(
      height: signatureHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 14, color: paperGold),
          Text(
            approved ? 'Decision: Approved' : 'Decision: Rejected',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (sig.note.isNotEmpty)
            Text(
              sig.note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: _ink),
            ),
          const SizedBox(height: 4),
          Text(
            '${sig.name}  |  ${sig.date}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          Text('Document ID: ${sig.documentId}', style: small, maxLines: 1),
          Text(
            'Signer fingerprint: ${sig.fingerprint}',
            style: small,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
