import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:material_ui/material_ui.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letterhead.dart';
import 'package:letter_signing/letters/letters_env.dart' show showError;
import 'package:letter_signing/letters/rich/rich_layout.dart'
    show a4Height, a4Width, headerHeight, pageMargin;
import 'package:letter_signing/meetings/meeting_print.dart';
import 'package:letter_signing/polls/models.dart';
import 'package:letter_signing/polls/poll_ui.dart';

const double _printScale = 3;
const double _footerHeight = 28;
const double _contentWidth = a4Width - 2 * pageMargin;

TextStyle _st(double size, {bool bold = false, Color color = paperInk}) =>
    TextStyle(
      fontSize: size,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: color,
      height: 1.4,
    );

/// The printed results as measured blocks: title, per-question counts (correct options
/// marked) and the score table.
List<PrintBlock> buildPollBlocks({
  required AppLocalizations l,
  required Poll poll,
  required PollResults results,
  required Letterhead head,
  TextDirection direction = TextDirection.rtl,
}) {
  final blocks = <PrintBlock>[];
  void line(
    String text, {
    double size = 12,
    bool bold = false,
    Color color = paperInk,
  }) {
    final st = _st(size, bold: bold, color: color);
    for (final s in splitLines(text, st, _contentWidth, direction)) {
      blocks.add(
        PrintBlock(size * 1.4 + 2, Text(s, style: st, softWrap: false)),
      );
    }
  }

  if (!head.isEmpty) {
    blocks.add(PrintBlock(headerHeight, LetterheadHeader(head: head)));
  }
  line(l.pollPrintTitle, size: 12, color: paperMid);
  line(poll.title, size: 20, bold: true);
  line(
    '${pollKindLabel(l, poll.kind)}  -  '
    '${l.pollParticipants(toPersianDigits(results.participants))}',
  );
  for (final (i, q) in results.questions.indexed) {
    blocks.add(const PrintBlock(12, SizedBox(height: 12)));
    line('${toPersianDigits(i + 1)}. ${q.text}', bold: true);
    for (final o in q.options) {
      final mark = (q.correct?.contains(o.id) ?? false) ? '[✓] ' : '';
      final names = o.voters == null || o.voters!.isEmpty
          ? ''
          : '  (${o.voters!.map((v) => v.displayName).join('، ')})';
      line('$mark${o.text}: ${toPersianDigits(o.count)}$names', size: 11);
    }
  }
  final scores = results.scores;
  if (scores != null) {
    blocks.add(const PrintBlock(12, SizedBox(height: 12)));
    line(l.pollScores, bold: true, color: paperBrand);
    for (final s in scores) {
      line(
        l.pollScoreLine(
          s.user.displayName,
          toPersianDigits(s.score),
          toPersianDigits(s.maxScore),
        ),
        size: 11,
      );
    }
  }
  return blocks;
}

/// A4 preview of the results with a print / save-as-PDF button (pages are rasterized like the
/// meeting minutes, so Persian text prints exactly as shown).
class PollPrintScreen extends StatefulWidget {
  const PollPrintScreen({
    super.key,
    required this.poll,
    required this.results,
    required this.head,
  });
  final Poll poll;
  final PollResults results;
  final Letterhead head;

  @override
  State<PollPrintScreen> createState() => _PollPrintState();
}

class _PollPrintState extends State<PollPrintScreen> {
  final List<GlobalKey> _keys = [];
  int _count = 0;
  bool _busy = false;

  Future<void> _print() async {
    setState(() => _busy = true);
    try {
      final doc = pw.Document(title: widget.poll.title);
      for (var i = 0; i < _count; i++) {
        final boundary =
            _keys[i].currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: _printScale);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final png = pw.MemoryImage(data!.buffer.asUint8List());
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Image(png, fit: pw.BoxFit.fill),
          ),
        );
      }
      final bytes = await doc.save();
      await Printing.layoutPdf(
        name: widget.poll.title,
        format: PdfPageFormat.a4,
        onLayout: (_) async => bytes,
      );
    } on Object catch (e) {
      if (mounted) {
        showError(context, AppLocalizations.of(context).paperPrintFailed('$e'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final blocks = buildPollBlocks(
      l: l,
      poll: widget.poll,
      results: widget.results,
      head: widget.head,
      direction: Directionality.of(context),
    );
    final capacity = a4Height - 2 * pageMargin - _footerHeight;
    final pages = paginateBlocks(
      blocks,
      firstCapacity: capacity,
      capacity: capacity,
    );
    _count = pages.length;
    while (_keys.length < pages.length) {
      _keys.add(GlobalKey());
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l.pollPrintTitle),
        actions: [
          IconButton(
            key: const ValueKey('poll-print-go'),
            tooltip: l.paperPrint,
            onPressed: _busy ? null : () => unawaited(_print()),
            icon: const Icon(Icons.print_outlined),
          ),
        ],
      ),
      body: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: pages.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (_, i) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: a4Width),
              child: AspectRatio(
                aspectRatio: a4Width / a4Height,
                child: FittedBox(
                  child: RepaintBoundary(
                    key: _keys[i],
                    child: MeetingPrintPage(
                      blocks: pages[i],
                      index: i,
                      count: pages.length,
                      footer: widget.poll.title,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
