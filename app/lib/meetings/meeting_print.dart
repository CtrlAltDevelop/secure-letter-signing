import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:material_ui/material_ui.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_detail_parts.dart'
    show decisionLabel, methodLabel;
import 'package:letter_signing/letters/letterhead.dart';
import 'package:letter_signing/letters/letters_env.dart' show showError;
import 'package:letter_signing/letters/rich/rich_layout.dart'
    show a4Height, a4Width, headerHeight, pageMargin;
import 'package:letter_signing/meetings/meeting_ui.dart';
import 'package:letter_signing/meetings/models.dart';
import 'package:letter_signing/workspace/models.dart';

const double _printScale = 3;
const double _footerHeight = 28;
const double _contentWidth = a4Width - 2 * pageMargin;
const double _rowHeight = 20;
const double _headingHeight = 40;
const double _signatureRowHeight = 40;
const double _bodyFont = 12;

/// One unbreakable piece of the printed minutes with its measured height.
class PrintBlock {
  const PrintBlock(this.height, this.child);
  final double height;
  final Widget child;
}

/// Splits [blocks] into A4 pages: the first page has [firstCapacity] points, later ones
/// [capacity]. A block taller than a page still gets a page of its own.
List<List<PrintBlock>> paginateBlocks(
  List<PrintBlock> blocks, {
  required double firstCapacity,
  required double capacity,
}) {
  final pages = <List<PrintBlock>>[[]];
  var used = 0.0;
  var limit = firstCapacity;
  for (final b in blocks) {
    if (used + b.height > limit && pages.last.isNotEmpty) {
      pages.add([]);
      used = 0;
      limit = capacity;
    }
    pages.last.add(b);
    used += b.height;
  }
  return pages;
}

/// The lines of [text] when laid out at [width], so long minutes can break across pages.
List<String> splitLines(
  String text,
  TextStyle style,
  double width,
  TextDirection direction,
) {
  if (text.isEmpty) return const [''];
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: direction,
  )..layout(maxWidth: width);
  final lines = <String>[];
  for (final m in painter.computeLineMetrics()) {
    final y = m.baseline - m.ascent + m.height / 2;
    final b = painter.getLineBoundary(
      painter.getPositionForOffset(Offset(width / 2, y)),
    );
    lines.add(text.substring(b.start, b.end).replaceAll('\n', ''));
  }
  painter.dispose();
  return lines;
}

const _ink = paperInk;

TextStyle _style(double size, {bool bold = false, Color color = _ink}) =>
    TextStyle(
      fontSize: size,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: color,
      height: 1.4,
    );

/// Builds the printed minutes as measured blocks: title, date, place, attendees with attendance,
/// the minutes text, resolutions with owners/due/status and the signature block.
List<PrintBlock> buildMeetingBlocks({
  required AppLocalizations l,
  required MeetingOut meeting,
  required Letterhead head,
  required String Function(int id) nameOf,
  TextDirection direction = TextDirection.rtl,
}) {
  final blocks = <PrintBlock>[];
  void line(
    String text, {
    double size = _bodyFont,
    bool bold = false,
    Color color = _ink,
  }) {
    final st = _style(size, bold: bold, color: color);
    for (final s in splitLines(text, st, _contentWidth, direction)) {
      blocks.add(
        PrintBlock(size * 1.4 + 2, Text(s, style: st, softWrap: false)),
      );
    }
  }

  void heading(String text) => blocks.add(
    PrintBlock(
      _headingHeight,
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(text, style: _style(14, bold: true, color: paperBrand)),
            const Divider(height: 4, color: paperGold),
          ],
        ),
      ),
    ),
  );

  if (!head.isEmpty) {
    blocks.add(PrintBlock(headerHeight, LetterheadHeader(head: head)));
  }
  final b = meeting.brief;
  line(l.meetingPrintTitle, size: 12, color: paperMid);
  line(b.title, size: 20, bold: true);
  line('${l.meetingPrintDate}: ${meetingWhen(b.startsAt, l.meetingNoDate)}');
  if (b.endsAt != null) {
    line('${l.meetingEnd}: ${meetingWhen(b.endsAt, '')}');
  }
  if (b.location.isNotEmpty) {
    line('${l.meetingLocation}: ${b.location}');
  }
  line(
    '${l.meetingFieldKind}: ${meetingKindLabel(l, b.kind)}  -  '
    '${l.meetingFieldStatus}: ${meetingStatusLabel(l, b.status)}',
  );

  heading(l.meetingAttendees);
  for (final a in meeting.attendees) {
    blocks.add(PrintBlock(_rowHeight, _attendeeRow(l, a)));
  }
  if (meeting.attendees.isEmpty) line(l.meetingNoAttendees);

  heading(l.meetingMinutes);
  line(meeting.description.isEmpty ? l.meetingNoMinutes : meeting.description);

  heading(l.meetingResolutions);
  if (meeting.resolutions.isEmpty) line(l.meetingNoResolutions);
  for (final (i, r) in meeting.resolutions.indexed) {
    line('${toPersianDigits(i + 1)}. ${r.text}', bold: true);
    line(_resolutionMeta(l, r, nameOf), size: 10.5, color: paperMid);
  }

  heading(l.meetingSignatures);
  if (meeting.signatures.isEmpty) line(l.meetingNoSignatures);
  for (final s in meeting.currentSignatures) {
    blocks.add(PrintBlock(_signatureRowHeight, _signatureRow(l, s)));
  }
  return blocks;
}

String _resolutionMeta(
  AppLocalizations l,
  Resolution r,
  String Function(int) nameOf,
) {
  final status = switch (r.status) {
    'done' => l.resolutionDone,
    'cancelled' => l.resolutionCancelled,
    _ => l.resolutionOpen,
  };
  return [
    if (r.ownerIds.isNotEmpty)
      '${l.resolutionOwners}: ${r.ownerIds.map(nameOf).join('، ')}',
    if (r.dueAt != null) '${l.resolutionDue}: ${formatJalaliDate(r.dueAt!)}',
    status,
  ].join('  |  ');
}

Widget _attendeeRow(AppLocalizations l, Attendee a) => SizedBox(
  height: _rowHeight,
  child: Row(
    children: [
      Expanded(
        flex: 5,
        child: Text(a.displayName, style: _style(_bodyFont), maxLines: 1),
      ),
      Expanded(
        flex: 3,
        child: Text(
          attendeeRoleLabel(l, a.role),
          style: _style(_bodyFont, color: paperMid),
          maxLines: 1,
        ),
      ),
      Expanded(
        flex: 3,
        child: Text(
          attendanceLabel(l, a.attendance),
          style: _style(_bodyFont, bold: true),
          maxLines: 1,
        ),
      ),
    ],
  ),
);

Widget _signatureRow(AppLocalizations l, MeetingSignature s) {
  final when = s.createdAt == null
      ? ''
      : '${formatJalaliDate(s.createdAt!)} ${formatJalaliTime(s.createdAt!)}';
  return SizedBox(
    height: _signatureRowHeight,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${s.user.displayName}: ${decisionLabel(l, s.decision)}',
          style: _style(_bodyFont, bold: true),
          maxLines: 1,
        ),
        Text(
          '${methodLabel(l, s.method)}  |  $when  |  '
          '${s.valid ? l.certValid : l.certInvalid}',
          style: _style(10, color: paperMid),
          maxLines: 1,
        ),
      ],
    ),
  );
}

/// One A4 sheet of printed minutes. Wrap in a RepaintBoundary to rasterize.
class MeetingPrintPage extends StatelessWidget {
  const MeetingPrintPage({
    super.key,
    required this.blocks,
    required this.index,
    required this.count,
    required this.footer,
  });
  final List<PrintBlock> blocks;
  final int index;
  final int count;
  final String footer;

  @override
  Widget build(BuildContext context) => Container(
    width: a4Width,
    height: a4Height,
    color: Colors.white,
    padding: const EdgeInsets.all(pageMargin),
    child: DefaultTextStyle(
      style: _style(_bodyFont),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRect(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final b in blocks) b.child],
              ),
            ),
          ),
          SizedBox(
            height: _footerHeight,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    footer,
                    style: _style(9, color: paperMid),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${toPersianDigits(index + 1)} / ${toPersianDigits(count)}',
                  style: _style(9),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Preview of the printed minutes with a print / save-as-PDF button (A4 pages are rasterized
/// like the letters' paper print, so any font and right-to-left text prints as shown).
class MeetingPrintScreen extends StatefulWidget {
  const MeetingPrintScreen({
    super.key,
    required this.meeting,
    required this.head,
    required this.directory,
  });
  final MeetingOut meeting;
  final Letterhead head;
  final List<UserRef> directory;

  @override
  State<MeetingPrintScreen> createState() => _MeetingPrintState();
}

class _MeetingPrintState extends State<MeetingPrintScreen> {
  final List<GlobalKey> _keys = [];
  int _count = 0;
  bool _busy = false;

  String _nameOf(int id) {
    for (final u in widget.directory) {
      if (u.id == id) return u.displayName;
    }
    for (final a in widget.meeting.attendees) {
      if (a.user?.id == id) return a.displayName;
    }
    return '#$id';
  }

  Future<void> _print() async {
    setState(() => _busy = true);
    try {
      final doc = pw.Document(title: widget.meeting.title);
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
        name: widget.meeting.title,
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
    final blocks = buildMeetingBlocks(
      l: l,
      meeting: widget.meeting,
      head: widget.head,
      nameOf: _nameOf,
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
        title: Text(l.meetingPrintTitle),
        actions: [
          IconButton(
            tooltip: l.paperPrint,
            onPressed: _busy ? null : () => unawaited(_print()),
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
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    boxShadow: [
                      BoxShadow(blurRadius: 8, color: Color(0x33000000)),
                    ],
                  ),
                  child: FittedBox(
                    child: RepaintBoundary(
                      key: _keys[i],
                      child: MeetingPrintPage(
                        blocks: pages[i],
                        index: i,
                        count: pages.length,
                        footer: widget.meeting.title,
                      ),
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
