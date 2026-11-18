import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:material_ui/material_ui.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:letter_signing/letters/letterhead.dart';
import 'package:letter_signing/letters/paper_pages.dart';
import 'package:letter_signing/letters/rich/rich_doc.dart';
import 'package:letter_signing/letters/rich/rich_layout.dart';

const double _printScale = 3; // 3x A4 points = ~216 dpi

/// Everything printed on the paper.
@immutable
class PaperDocument {
  const PaperDocument({
    required this.head,
    required this.title,
    required this.number,
    required this.date,
    required this.text,
    this.signatures = const [],
  });
  final Letterhead head;
  final String title;
  final String number;
  final String date;
  final RichDoc text;
  final List<PaperSignature> signatures;
}

/// Scrollable A4 pages of a [PaperDocument]. Call [PaperPreviewState.print] through a GlobalKey.
class PaperPreview extends StatefulWidget {
  const PaperPreview({super.key, required this.doc, required this.fontSize});
  final PaperDocument doc;
  final double fontSize;

  @override
  State<PaperPreview> createState() => PaperPreviewState();
}

class PaperPreviewState extends State<PaperPreview> {
  final List<GlobalKey> _keys = [];
  int _count = 0;

  /// Rasterizes every page (so any font or right-to-left text prints as shown) and opens the print dialog.
  Future<void> print() async {
    final doc = pw.Document(title: widget.doc.title);
    for (var i = 0; i < _count; i++) {
      final boundary =
          _keys[i].currentContext!.findRenderObject()! as RenderRepaintBoundary;
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
      name: widget.doc.title,
      format: PdfPageFormat.a4,
      onLayout: (_) async => bytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doc;
    final pages = paginateRich(
      d.text,
      widget.fontSize,
      signatureCount: d.signatures.length,
    );
    _count = pages.length;
    while (_keys.length < pages.length) {
      _keys.add(GlobalKey());
    }
    return ColoredBox(
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
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  boxShadow: [
                    BoxShadow(blurRadius: 8, color: Color(0x33000000)),
                  ],
                ),
                child: FittedBox(
                  child: RepaintBoundary(
                    key: _keys[i],
                    child: PaperPage(
                      head: d.head,
                      index: i,
                      count: pages.length,
                      doc: d.text,
                      slices: pages[i],
                      fontSize: widget.fontSize,
                      title: d.title,
                      number: d.number,
                      date: d.date,
                      signatures: d.signatures,
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
