import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';

/// One bar: the x label (already Jalali) and its value.
class ChartPoint {
  const ChartPoint(this.label, this.value);
  final String label;
  final num value;
}

/// Points of a server series `[{date, label?, value}]`.
List<ChartPoint> pointsOf(Object? series) => [
  if (series is List)
    for (final e in series)
      if (e is Map)
        ChartPoint(_label(e), e['value'] is num ? e['value'] as num : 0),
];

String _label(Map e) {
  final label = e['label'];
  if (label is String && label.isNotEmpty) return label;
  final d = DateTime.tryParse('${e['date']}');
  return d == null ? '' : formatJalaliDate(d);
}

/// A small bar chart drawn left to right whatever the text direction (time axes read LTR),
/// with the first and last label under it and the maximum above.
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.points,
    this.height = 110,
    this.color,
  });

  final List<ChartPoint> points;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.labelSmall;
    final max = points.fold<num>(0, (m, p) => p.value > m ? p.value : m);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(toPersianDigits(max), style: small),
          SizedBox(
            height: height,
            child: CustomPaint(
              painter: _BarPainter(
                points,
                max,
                color ?? scheme.primary,
                scheme.outlineVariant,
              ),
            ),
          ),
          if (points.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(toPersianDigits(points.first.label), style: small),
                Text(toPersianDigits(points.last.label), style: small),
              ],
            ),
        ],
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.points, this.max, this.color, this.axis);

  final List<ChartPoint> points;
  final num max;
  final Color color;
  final Color axis;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()..color = axis,
    );
    if (points.isEmpty || max <= 0) return;
    final slot = size.width / points.length;
    final w = (slot * 0.7).clamp(1.0, 24.0);
    final paint = Paint()..color = color;
    for (var i = 0; i < points.length; i++) {
      final h = size.height * (points[i].value / max);
      canvas.drawRect(
        Rect.fromLTWH(i * slot + (slot - w) / 2, size.height - h, w, h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.points != points || old.max != max || old.color != color;
}
