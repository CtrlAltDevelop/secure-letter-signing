import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/gantt/gantt_models.dart';
import 'package:letter_signing/gantt/gantt_scale.dart';
import 'package:letter_signing/theme/app_theme.dart';

const double ganttRowHeight = 38;
const double ganttHeaderRowHeight = 22;
const double _barHeight = 18;
const double _edgeGrab = 7;

/// What a drag on a bar changes.
enum DragMode { move, resizeStart, resizeEnd }

/// A drag in progress: the row's task, what it changes and how far (in days).
@immutable
class BarDrag {
  const BarDrag(this.taskId, this.mode, this.days);
  final String taskId;
  final DragMode mode;
  final int days;
}

/// Where a bar sits: a row's rectangle on the timeline, or null when it has no dates.
Rect? barRect(GanttScale scale, GanttRow row, int index, {BarDrag? drag}) {
  final start = row.start;
  final end = row.end;
  if (start == null || end == null) return null;
  var s = start;
  var e = end;
  if (drag != null && !row.isPhase && drag.taskId == row.item!.taskId) {
    final d = Duration(days: drag.days);
    switch (drag.mode) {
      case DragMode.move:
        s = s.add(d);
        e = e.add(d);
      case DragMode.resizeStart:
        s = s.add(d);
        if (s.isAfter(e)) s = e;
      case DragMode.resizeEnd:
        e = e.add(d);
        if (e.isBefore(s)) e = s;
    }
  }
  final left = scale.x(s);
  final right = scale.x(e) + scale.dayWidth;
  final top = index * ganttRowHeight + (ganttRowHeight - _barHeight) / 2;
  return Rect.fromLTRB(
    left,
    top,
    right < left + 4 ? left + 4 : right,
    top + _barHeight,
  );
}

/// Which bar and part of it lies under [at] (timeline coordinates), if any.
({String taskId, DragMode mode})? hitBar(
  GanttScale scale,
  List<GanttRow> rows,
  Offset at,
) {
  final index = (at.dy / ganttRowHeight).floor();
  if (index < 0 || index >= rows.length || rows[index].isPhase) return null;
  final rect = barRect(scale, rows[index], index);
  if (rect == null || !rect.inflate(2).contains(at)) return null;
  final id = rows[index].item!.taskId;
  if (at.dx <= rect.left + _edgeGrab && rect.width > _edgeGrab * 3) {
    return (taskId: id, mode: DragMode.resizeStart);
  }
  if (at.dx >= rect.right - _edgeGrab && rect.width > _edgeGrab * 3) {
    return (taskId: id, mode: DragMode.resizeEnd);
  }
  return (taskId: id, mode: DragMode.move);
}

/// The time axis header: two rows of labelled segments.
class GanttHeaderPainter extends CustomPainter {
  GanttHeaderPainter({
    required this.scale,
    required this.color,
    required this.line,
  });
  final GanttScale scale;
  final Color color;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (final (row, segments) in [(0, scale.top), (1, scale.bottom)]) {
      final top = row * ganttHeaderRowHeight;
      for (final seg in segments) {
        final left = seg.startDay * scale.dayWidth;
        final width = seg.days * scale.dayWidth;
        canvas.drawLine(
          Offset(left, top),
          Offset(left, top + ganttHeaderRowHeight),
          stroke,
        );
        if (width < 10) continue;
        final tp = TextPainter(
          text: TextSpan(
            text: seg.label,
            style: TextStyle(color: color, fontSize: 11.5),
          ),
          textDirection: TextDirection.rtl,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: width - 4);
        tp.paint(
          canvas,
          Offset(
            left + (width - tp.width) / 2,
            top + (ganttHeaderRowHeight - tp.height) / 2,
          ),
        );
      }
    }
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      stroke,
    );
  }

  @override
  bool shouldRepaint(GanttHeaderPainter old) =>
      old.scale.zoom != scale.zoom ||
      old.scale.origin != scale.origin ||
      old.scale.days != scale.days ||
      old.color != color;
}

/// Bars, summary bars, weekend / holiday shading, the today line and dependency arrows.
class GanttTimelinePainter extends CustomPainter {
  GanttTimelinePainter({
    required this.rows,
    required this.links,
    required this.scale,
    required this.marks,
    required this.scheme,
    required this.today,
    this.selected,
    this.drag,
  });

  final List<GanttRow> rows;
  final List<GanttLink> links;
  final GanttScale scale;
  final GanttCalendarMarks marks;
  final ColorScheme scheme;
  final DateTime today;
  final String? selected;
  final BarDrag? drag;

  @override
  void paint(Canvas canvas, Size size) {
    _shading(canvas, size);
    _grid(canvas, size);
    for (final (i, row) in rows.indexed) {
      _bar(canvas, row, i);
    }
    _links(canvas);
    _todayLine(canvas, size);
  }

  void _shading(Canvas canvas, Size size) {
    if (scale.dayWidth < 5) return;
    final weekend = Paint()..color = scheme.onSurface.withValues(alpha: 0.05);
    final holiday = Paint()..color = Tokens.error.withValues(alpha: 0.10);
    for (var i = 0; i < scale.days; i++) {
      final day = scale.dayAt(i);
      final paint = marks.isHoliday(day)
          ? holiday
          : (marks.isWeekend(day) ? weekend : null);
      if (paint != null) {
        canvas.drawRect(
          Rect.fromLTWH(i * scale.dayWidth, 0, scale.dayWidth, size.height),
          paint,
        );
      }
    }
  }

  void _grid(Canvas canvas, Size size) {
    final line = Paint()
      ..color = scheme.outlineVariant
      ..strokeWidth = 1;
    for (var i = 1; i <= rows.length; i++) {
      canvas.drawLine(
        Offset(0, i * ganttRowHeight),
        Offset(size.width, i * ganttRowHeight),
        line,
      );
    }
    for (final seg
        in scale.zoom == GanttZoom.daily ? scale.top : scale.bottom) {
      final x = seg.startDay * scale.dayWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
  }

  void _bar(Canvas canvas, GanttRow row, int index) {
    final rect = barRect(scale, row, index, drag: drag);
    if (rect == null) return;
    final isSelected = row.key == selected;
    if (row.isPhase) {
      final paint = Paint()..color = scheme.onSurface.withValues(alpha: 0.75);
      final bar = Rect.fromLTWH(rect.left, rect.center.dy - 4, rect.width, 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(2)),
        paint,
      );
      for (final x in [bar.left, bar.right]) {
        canvas.drawPath(
          Path()
            ..moveTo(x - 4, bar.bottom - 1)
            ..lineTo(x + 4, bar.bottom - 1)
            ..lineTo(x, bar.bottom + 5)
            ..close(),
          paint,
        );
      }
      return;
    }
    final base = scheme.primary;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rrect, Paint()..color = base.withValues(alpha: 0.25));
    final done = (row.progress.clamp(0, 100)) / 100;
    if (done > 0) {
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, rect.width * done, rect.height),
        Paint()..color = base,
      );
      canvas.restore();
    }
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.2 : 1
        ..color = isSelected ? scheme.secondary : base,
    );
  }

  int _indexOf(String taskId) =>
      rows.indexWhere((r) => !r.isPhase && r.item!.taskId == taskId);

  void _links(Canvas canvas) {
    for (final link in links) {
      final p = _indexOf(link.predecessorId);
      final s = _indexOf(link.successorId);
      if (p < 0 || s < 0) continue;
      final from = barRect(scale, rows[p], p, drag: drag);
      final to = barRect(scale, rows[s], s, drag: drag);
      if (from == null || to == null) continue;
      _arrow(
        canvas,
        Offset(from.right, from.center.dy),
        Offset(to.left, to.center.dy),
        link.conflict,
      );
    }
  }

  void _arrow(Canvas canvas, Offset start, Offset end, bool conflict) {
    final color = conflict ? Tokens.error : scheme.onSurfaceVariant;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = conflict ? 1.8 : 1.2;
    final mid = start.dx + 8;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(mid, start.dy);
    if (end.dx - 8 >= mid) {
      path
        ..lineTo(mid, end.dy)
        ..lineTo(end.dx, end.dy);
    } else {
      final turn =
          start.dy + (end.dy >= start.dy ? 1 : -1) * ganttRowHeight / 2;
      path
        ..lineTo(mid, turn)
        ..lineTo(end.dx - 8, turn)
        ..lineTo(end.dx - 8, end.dy)
        ..lineTo(end.dx, end.dy);
    }
    canvas.drawPath(path, paint);
    canvas.drawPath(
      Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(end.dx - 6, end.dy - 3.5)
        ..lineTo(end.dx - 6, end.dy + 3.5)
        ..close(),
      Paint()..color = color,
    );
  }

  void _todayLine(Canvas canvas, Size size) {
    final offset = daysBetween(scale.origin, today);
    if (offset < 0 || offset >= scale.days) return;
    final x = offset * scale.dayWidth + scale.dayWidth / 2;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = Tokens.warn
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(GanttTimelinePainter old) => true;
}
