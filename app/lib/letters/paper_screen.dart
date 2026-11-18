import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:material_ui/material_ui.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:letter_signing/letters/letter_widgets.dart';
import 'package:letter_signing/letters/letterhead.dart';
import 'package:letter_signing/letters/paper_pages.dart';

const double _minFont = 9;
const double _maxFont = 20;
const double _defaultFont = 12;
const double _printScale = 3; // 3x A4 points = ~216 dpi

/// The letter as it will look on A4 paper: letterhead, adjustable font size, print / save PDF.
class PaperScreen extends StatefulWidget {
  const PaperScreen({
    super.key,
    required this.head,
    required this.title,
    required this.subtitle,
    required this.text,
  });
  final Letterhead head;
  final String title;
  final String subtitle;
  final String text;

  @override
  State<PaperScreen> createState() => _PaperScreenState();
}

class _PaperScreenState extends State<PaperScreen> {
  double _font = _defaultFont;
  bool _busy = false;
  String? _error;
  final List<GlobalKey> _keys = [];

  Future<void> _print(int count) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final doc = pw.Document(title: widget.title);
      for (var i = 0; i < count; i++) {
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
        name: widget.title,
        format: PdfPageFormat.a4,
        onLayout: (_) async => bytes,
      );
    } on Object catch (e) {
      if (mounted) setState(() => _error = 'Could not print: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rtl = isRtlText(widget.text);
    final pages = paginate(widget.text, _font, rtl: rtl);
    while (_keys.length < pages.length) {
      _keys.add(GlobalKey());
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paper preview'),
        actions: [
          IconButton(
            tooltip: 'Print / save PDF',
            onPressed: _busy ? null : () => unawaited(_print(pages.length)),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          _FontBar(
            value: _font,
            pageCount: pages.length,
            onChanged: (v) => setState(() => _font = v),
          ),
          if (_error != null) ErrorBanner(_error!),
          Expanded(
            child: ColoredBox(
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
                              head: widget.head,
                              index: i,
                              count: pages.length,
                              text: pages[i],
                              fontSize: _font,
                              rtl: rtl,
                              title: widget.title,
                              subtitle: widget.subtitle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FontBar extends StatelessWidget {
  const _FontBar({
    required this.value,
    required this.pageCount,
    required this.onChanged,
  });
  final double value;
  final int pageCount;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      children: [
        const Icon(Icons.text_fields, size: 18),
        Expanded(
          child: Slider(
            min: _minFont,
            max: _maxFont,
            divisions: (_maxFont - _minFont).round(),
            value: value,
            label: '${value.round()} pt',
            onChanged: onChanged,
          ),
        ),
        Text('${value.round()} pt  |  A4  |  $pageCount p'),
      ],
    ),
  );
}
