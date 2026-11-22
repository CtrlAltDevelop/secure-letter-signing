import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:material_ui/material_ui.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:letter_signing/gantt/gantt_api.dart';
import 'package:letter_signing/gantt/gantt_models.dart';
import 'package:letter_signing/gantt/gantt_scale.dart';
import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letters_env.dart' show showError;
import 'package:letter_signing/theme/widgets.dart';

/// A4 landscape at 96 dpi, in logical pixels; each page is rasterized to the PDF like the
/// meeting minutes, so Persian text prints exactly as shown.
const double printPageWidth = 1123;
const double printPageHeight = 794;
const double _margin = 28;
const double _titleHeight = 46;
const double _headerHeight = 34;
const double _rowH = 22;
const double _tableWidth = 400;
const double _printScale = 3;

/// How many chart rows fit on one page.
int rowsPerPage() =>
    ((printPageHeight - 2 * _margin - _titleHeight - _headerHeight - 18) /
            _rowH)
        .floor();

/// Splits [rows] into pages (always at least one).
List<List<GanttPrintRow>> paginateRows(List<GanttPrintRow> rows) {
  final per = rowsPerPage();
  if (rows.isEmpty) return const [[]];
  return [
    for (var i = 0; i < rows.length; i += per)
      rows.sublist(i, i + per > rows.length ? rows.length : i + per),
  ];
}

class GanttPrintScreen extends StatefulWidget {
  const GanttPrintScreen({
    super.key,
    required this.api,
    required this.projectId,
  });
  final GanttApi api;
  final String projectId;

  @override
  State<GanttPrintScreen> createState() => _GanttPrintScreenState();
}

class _GanttPrintScreenState extends State<GanttPrintScreen> {
  late final Future<GanttPrint> _data = widget.api.print(widget.projectId);
  final List<GlobalKey> _keys = [];
  int _count = 0;
  bool _busy = false;

  Future<void> _printPdf(String name) async {
    setState(() => _busy = true);
    try {
      final doc = pw.Document(title: name);
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
            pageFormat: PdfPageFormat.a4.landscape,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Image(png, fit: pw.BoxFit.fill),
          ),
        );
      }
      final bytes = await doc.save();
      await Printing.layoutPdf(
        name: name,
        format: PdfPageFormat.a4.landscape,
        onLayout: (_) async => bytes,
      );
    } on Object catch (e) {
      if (mounted)
        showError(context, AppLocalizations.of(context).paperPrintFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.gnPrint),
        actions: [
          IconButton(
            key: const ValueKey('gantt-print-go'),
            tooltip: l.paperPrint,
            onPressed: _busy || _count == 0
                ? null
                : () => unawaited(_printPdf(l.gnPrint)),
            icon: const Icon(Icons.print_outlined),
          ),
        ],
      ),
      body: FutureBuilder<GanttPrint>(
        future: _data,
        builder: (context, snap) {
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_outlined,
              title: l.gnLoadFailed,
              message: '${snap.error}',
            );
          }
          final data = snap.data;
          if (data == null)
            return const Center(child: CircularProgressIndicator());
          final pages = paginateRows(data.rows);
          if (_count != pages.length) {
            // The app bar button reads _count; rebuild it once pages exist.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _count = pages.length);
            });
          }
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
                  constraints: const BoxConstraints(maxWidth: printPageWidth),
                  child: AspectRatio(
                    aspectRatio: printPageWidth / printPageHeight,
                    child: FittedBox(
                      child: RepaintBoundary(
                        key: _keys[i],
                        child: GanttPrintPage(
                          data: data,
                          rows: pages[i],
                          firstRow: i * rowsPerPage(),
                          index: i,
                          count: pages.length,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One printed page: white, black ink, the chart's rows from [firstRow].
class GanttPrintPage extends StatelessWidget {
  const GanttPrintPage({
    super.key,
    required this.data,
    required this.rows,
    required this.firstRow,
    required this.index,
    required this.count,
  });
  final GanttPrint data;
  final List<GanttPrintRow> rows;
  final int firstRow;
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final footer = toPersianDigits(
      '${formatJalaliDate(DateTime.now())}  ·  ${index + 1}/$count'
      '${data.rows.any((r) => r.critical) ? '  ·  ${l.gnCritical}' : ''}',
    );
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: printPageWidth,
        height: printPageHeight,
        color: Colors.white,
        child: CustomPaint(
          size: const Size(printPageWidth, printPageHeight),
          painter: _PrintPainter(
            data: data,
            rows: rows,
            firstRow: firstRow,
            title:
                '${l.gnPrintTitle(data.name)}  —  ${l.gnProgress(toPersianDigits(data.progress))}',
            footer: footer,
          ),
        ),
      ),
    );
  }
}

class _PrintPainter extends CustomPainter {
  _PrintPainter({
    required this.data,
    required this.rows,
    required this.firstRow,
    required this.title,
    required this.footer,
  });
  final GanttPrint data;
  final List<GanttPrintRow> rows;
  final int firstRow;
  final String title;
  final String footer;

  static const _ink = Colors.black;

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    double width = 200,
    double size = 10,
    bool bold = false,
    TextAlign align = TextAlign.right,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: _ink,
          fontSize: size,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: align,
      maxLines: 1,
      ellipsis: '…',
    )..layout(minWidth: width, maxWidth: width);
    tp.paint(canvas, at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFFBBBBBB)
      ..strokeWidth = 0.7;
    _text(
      canvas,
      title,
      const Offset(_margin, _margin),
      width: size.width - 2 * _margin,
      size: 15,
      bold: true,
    );
    final top = _margin + _titleHeight;
    final timeLeft = _margin;
    final timeWidth = size.width - 2 * _margin - _tableWidth - 12;
    final tableRight = size.width - _margin;

    final start = data.start;
    final end = data.end;
    final scale = start == null || end == null
        ? null
        : GanttScale.fit(start, end, GanttZoom.monthly);
    final k = scale == null ? 0.0 : timeWidth / scale.width;

    // Month header and shading.
    if (scale != null) {
      for (final seg in scale.bottom) {
        final x = timeLeft + seg.startDay * scale.dayWidth * k;
        canvas.drawLine(
          Offset(x, top),
          Offset(x, top + _headerHeight + rows.length * _rowH),
          line,
        );
        _text(
          canvas,
          seg.label,
          Offset(x, top + 10),
          width: seg.days * scale.dayWidth * k,
          size: 8,
          align: TextAlign.center,
        );
      }
      for (final seg in scale.top) {
        _text(
          canvas,
          seg.label,
          Offset(timeLeft + seg.startDay * scale.dayWidth * k, top),
          width: seg.days * scale.dayWidth * k,
          size: 8,
          bold: true,
          align: TextAlign.center,
        );
      }
      final dayW = scale.dayWidth * k;
      for (var i = 0; i < scale.days; i++) {
        final d = scale.dayAt(i);
        final shade = data.marks.isHoliday(d)
            ? const Color(0x22D65959)
            : (data.marks.isWeekend(d) ? const Color(0x14000000) : null);
        if (shade != null) {
          canvas.drawRect(
            Rect.fromLTWH(
              timeLeft + i * dayW,
              top + _headerHeight,
              dayW,
              rows.length * _rowH,
            ),
            Paint()..color = shade,
          );
        }
      }
    }
    // Table header.
    _text(
      canvas,
      'WBS',
      Offset(tableRight - 40, top + 8),
      width: 40,
      bold: true,
    );
    canvas.drawLine(
      Offset(_margin, top + _headerHeight),
      Offset(size.width - _margin, top + _headerHeight),
      line,
    );

    final byWbs = <String, int>{for (final (i, r) in rows.indexed) r.wbs: i};
    for (final (i, r) in rows.indexed) {
      final y = top + _headerHeight + i * _rowH;
      canvas.drawLine(
        Offset(_margin, y + _rowH),
        Offset(size.width - _margin, y + _rowH),
        line,
      );
      _text(canvas, r.wbs, Offset(tableRight - 40, y + 5), width: 40, size: 9);
      final indent = (r.level - 1) * 10.0;
      _text(
        canvas,
        r.title,
        Offset(tableRight - 270, y + 5),
        width: 226 - indent,
        bold: r.isPhase || r.critical,
      );
      final dates = r.start == null || r.end == null
          ? ''
          : '${formatJalaliDate(r.start!)} - ${formatJalaliDate(r.end!)}';
      _text(
        canvas,
        dates,
        Offset(_margin + timeWidth + 12, y + 5),
        width: 128,
        size: 8.5,
        align: TextAlign.left,
      );
      if (scale != null && r.start != null && r.end != null) {
        final left = timeLeft + scale.x(r.start!) * k;
        final right = timeLeft + (scale.x(r.end!) + scale.dayWidth) * k;
        final bar = Rect.fromLTRB(
          left,
          y + 5,
          right < left + 2 ? left + 2 : right,
          y + _rowH - 5,
        );
        if (r.isPhase) {
          canvas.drawRect(
            Rect.fromLTRB(bar.left, y + 8, bar.right, y + _rowH - 8),
            Paint()..color = _ink,
          );
        } else {
          canvas.drawRect(bar, Paint()..color = const Color(0x55000000));
          if (r.critical) {
            canvas.drawRect(
              bar,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2
                ..color = _ink,
            );
          }
          canvas.drawRect(
            Rect.fromLTWH(
              bar.left,
              bar.top,
              bar.width * (r.progress.clamp(0, 100)) / 100,
              bar.height,
            ),
            Paint()..color = _ink,
          );
        }
      }
    }
    // Dependencies between rows on this page.
    if (scale != null) {
      for (final (from, to, conflict) in data.links) {
        final a = byWbs[from];
        final b = byWbs[to];
        if (a == null || b == null) continue;
        final ra = rows[a];
        final rb = rows[b];
        if (ra.end == null || rb.start == null) continue;
        final paint = Paint()
          ..color = conflict ? const Color(0xFFD65959) : const Color(0xFF666666)
          ..style = PaintingStyle.stroke
          ..strokeWidth = conflict ? 1.4 : 0.9;
        final p = Offset(
          timeLeft + (scale.x(ra.end!) + scale.dayWidth) * k,
          top + _headerHeight + a * _rowH + _rowH / 2,
        );
        final q = Offset(
          timeLeft + scale.x(rb.start!) * k,
          top + _headerHeight + b * _rowH + _rowH / 2,
        );
        canvas.drawPath(
          Path()
            ..moveTo(p.dx, p.dy)
            ..lineTo(p.dx + 4, p.dy)
            ..lineTo(p.dx + 4, q.dy)
            ..lineTo(q.dx, q.dy),
          paint,
        );
      }
    }
    _text(
      canvas,
      footer,
      Offset(_margin, size.height - _margin + 4),
      width: size.width - 2 * _margin,
      size: 9,
      align: TextAlign.center,
    );
  }

  @override
  bool shouldRepaint(_PrintPainter old) => true;
}
