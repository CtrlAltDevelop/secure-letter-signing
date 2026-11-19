import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letterhead.dart';
import 'package:letter_signing/letters/rich/rich_doc.dart';
import 'package:letter_signing/letters/rich/rich_layout.dart';

const Color _ink = paperInk;

/// One A4 sheet. Wrap in a RepaintBoundary to rasterize for printing.
class PaperPage extends StatelessWidget {
  const PaperPage({
    super.key,
    required this.head,
    required this.index,
    required this.count,
    required this.doc,
    required this.slices,
    required this.fontSize,
    required this.title,
    required this.number,
    required this.date,
    this.signatures = const [],
    this.paraphs = const [],
  });
  final Letterhead head;
  final int index;
  final int count;
  final RichDoc doc;
  final List<PageSlice> slices;
  final double fontSize;
  final String title;
  final String number;
  final String date;
  final List<PaperSignature> signatures;
  final List<PaperParaph> paraphs;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final dir = paraIsRtl(doc.paras.first, doc.text)
        ? TextDirection.rtl
        : TextDirection.ltr;
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
                height: headerHeight,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: LetterheadHeader(head: head),
                ),
              ),
              SizedBox(
                height: titleHeight,
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
                            l.paperNumber(number),
                            style: const TextStyle(fontSize: 12, color: _ink),
                          ),
                          Text(
                            l.paperDate(date),
                            style: const TextStyle(fontSize: 12, color: _ink),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l.paperSubject(title),
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
              child: PaperBody(
                doc: doc,
                slices: slices,
                font: fontSize,
                ink: _ink,
              ),
            ),
            if (index == count - 1)
              for (final sig in signatures) SignatureBlock(sig: sig),
            if (index == count - 1 && paraphs.isNotEmpty)
              ParaphStrip(paraphs: paraphs),
            SizedBox(
              height: footerHeight,
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
    required this.seal,
    required this.documentId,
  });
  final String decision; // approved | rejected
  final String note;
  final String name;
  final String date;
  final String seal;
  final String documentId;
}

/// One paraph (initials) printed under the signatures.
class PaperParaph {
  const PaperParaph({
    required this.name,
    required this.method,
    required this.date,
  });
  final String name;
  final String method;
  final String date;
}

/// The paraphs of the letter as a compact strip: name, method and time of each.
class ParaphStrip extends StatelessWidget {
  const ParaphStrip({super.key, required this.paraphs});
  final List<PaperParaph> paraphs;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SizedBox(
      height: paraphHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 8, color: paperGold),
          Text(
            l.paperParaphs,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          Expanded(
            child: Text(
              [for (final p in paraphs) '${p.name} (${p.method}، ${p.date})']
                  .join(' | '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, color: paperMid),
            ),
          ),
        ],
      ),
    );
  }
}

class SignatureBlock extends StatelessWidget {
  const SignatureBlock({super.key, required this.sig});
  final PaperSignature sig;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
            approved ? l.paperDecisionApproved : l.paperDecisionRejected,
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
          Text(l.paperDocumentId(sig.documentId), style: small, maxLines: 1),
          Text(
            l.paperSeal(sig.seal),
            style: small,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
