import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:material_ui/material_ui.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letters_env.dart' show showError;
import 'package:letter_signing/letters/rich/rich_layout.dart'
    show a4Height, a4Width, pageMargin;
import 'package:letter_signing/meetings/meeting_print.dart';
import 'package:letter_signing/monitor/monitor_env.dart';
import 'package:letter_signing/monitor/report_ui.dart';
import 'package:letter_signing/workspace/models.dart';

const double _footerHeight = 28;
const double _rowHeight = 20;
const double _printScale = 3;

/// Printable overdue-task rows as unbreakable one-line blocks (heading first).
List<PrintBlock> overdueBlocks(
  AppLocalizations l,
  List<Map<String, dynamic>> rows,
) {
  const ink = TextStyle(fontSize: 10, color: Colors.black);
  Widget line(List<String> cells, {bool bold = false}) => SizedBox(
    height: _rowHeight,
    child: Row(
      children: [
        for (final (i, c) in cells.indexed)
          Expanded(
            flex: i == 0 ? 4 : 2,
            child: Text(
              c,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bold ? ink.copyWith(fontWeight: FontWeight.bold) : ink,
            ),
          ),
      ],
    ),
  );
  return [
    PrintBlock(
      _rowHeight * 2,
      Padding(
        padding: const EdgeInsets.only(bottom: _rowHeight),
        child: Text(
          l.monPrintTitle,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ),
    PrintBlock(
      _rowHeight,
      line([
        l.monTasks,
        l.monFilterProject,
        l.monFilterPerson,
        l.monLate,
      ], bold: true),
    ),
    for (final r in rows)
      PrintBlock(
        _rowHeight,
        line([
          asString(r['title']),
          asString(r['project_name']),
          [for (final o in asMapList(r['owners'])) personName(o)].join('، '),
          '${fmtNum(r['days_late'])} ${l.monDays}',
        ]),
      ),
  ];
}

/// A4 preview of the overdue list with a print / save-as-PDF button (pages are rasterized
/// like the meeting minutes, so Persian text prints as shown).
class TasksPrintScreen extends StatefulWidget {
  const TasksPrintScreen({
    super.key,
    required this.env,
    this.project = '',
    this.label,
    this.person,
    this.customer = '',
  });
  final MonitorEnv env;
  final String project;
  final int? label;
  final int? person;
  final String customer;

  @override
  State<TasksPrintScreen> createState() => _TasksPrintState();
}

class _TasksPrintState extends State<TasksPrintScreen> {
  late final Future<Map<String, dynamic>> _data = widget.env.api.tasks(
    project: widget.project,
    label: widget.label,
    person: widget.person,
    customer: widget.customer,
    printable: true,
  );
  final List<GlobalKey> _keys = [];
  int _count = 0;
  bool _busy = false;

  Future<void> _print(String name) async {
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
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Image(png, fit: pw.BoxFit.fill),
          ),
        );
      }
      final bytes = await doc.save();
      await Printing.layoutPdf(
        name: name,
        format: PdfPageFormat.a4,
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
        title: Text(l.monPrintTitle),
        actions: [
          IconButton(
            key: const ValueKey('tasks-print-go'),
            tooltip: l.paperPrint,
            onPressed: _busy || _count == 0
                ? null
                : () => unawaited(_print(l.monPrintTitle)),
            icon: const Icon(Icons.print_outlined),
          ),
        ],
      ),
      body: ReportView(
        load: () => _data,
        builder: (context, data) {
          final capacity = a4Height - 2 * pageMargin - _footerHeight;
          final pages = paginateBlocks(
            overdueBlocks(l, asMapList(data['overdue'])),
            firstCapacity: capacity,
            capacity: capacity,
          );
          _count = pages.length;
          while (_keys.length < pages.length) {
            _keys.add(GlobalKey());
          }
          final footer = toPersianDigits(formatJalaliDate(DateTime.now()));
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
                    child: FittedBox(
                      child: RepaintBoundary(
                        key: _keys[i],
                        child: MeetingPrintPage(
                          blocks: pages[i],
                          index: i,
                          count: pages.length,
                          footer: footer,
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
