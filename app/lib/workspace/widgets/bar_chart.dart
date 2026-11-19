import 'package:material_ui/material_ui.dart';

/// One named run of values, one per group of the chart.
@immutable
class ChartSeries {
  const ChartSeries(this.name, this.color, this.values, {this.valueColors});
  final String name;
  final Color color;

  /// Optional colour per value (one bar per group in different colours).
  final List<Color>? valueColors;
  final List<num> values;
}

const _groupMin = 52.0;
const _labelH = 22.0;

/// Grouped bars drawn with a [CustomPainter] (no chart package, works offline). Groups run
/// right-to-left in an RTL context so time reads like the table next to it; scrolls
/// horizontally when the groups do not fit. [semanticsLabel] summarises it for screen readers.
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.labels,
    required this.series,
    required this.semanticsLabel,
    this.height = 200,
  });

  final List<String> labels;
  final List<ChartSeries> series;
  final String semanticsLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      label: semanticsLabel,
      image: true,
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, box) {
            final width = labels.length * _groupMin > box.maxWidth
                ? labels.length * _groupMin
                : box.maxWidth;
            final paint = CustomPaint(
              size: Size(width, height),
              painter: _BarPainter(
                labels: labels,
                series: series,
                rtl: rtl,
                grid: scheme.outlineVariant,
                text: scheme.onSurfaceVariant,
                textStyle: Theme.of(context).textTheme.labelSmall,
              ),
            );
            if (width == box.maxWidth) return paint;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: paint,
            );
          },
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.labels,
    required this.series,
    required this.rtl,
    required this.grid,
    required this.text,
    required this.textStyle,
  });

  final List<String> labels;
  final List<ChartSeries> series;
  final bool rtl;
  final Color grid;
  final Color text;
  final TextStyle? textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final plotH = size.height - _labelH;
    var top = 1.0;
    for (final s in series) {
      for (final v in s.values) {
        if (v > top) top = v.toDouble();
      }
    }
    final line = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = plotH * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    final n = labels.length;
    if (n == 0 || series.isEmpty) return;
    final group = size.width / n;
    final bar = (group * 0.7) / series.length;
    for (var g = 0; g < n; g++) {
      final slot = rtl ? n - 1 - g : g;
      final left = slot * group + group * 0.15;
      for (var s = 0; s < series.length; s++) {
        final values = series[s].values;
        final v = g < values.length ? values[g].toDouble() : 0.0;
        final h = v <= 0 ? 0.0 : plotH * v / top;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left + s * bar, plotH - h, bar - 2, h),
            const Radius.circular(3),
          ),
          Paint()..color = _colorOf(series[s], g),
        );
      }
      final tp = TextPainter(
        text: TextSpan(
          text: labels[g],
          style: textStyle?.copyWith(color: text),
        ),
        textDirection: TextDirection.rtl,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: group);
      tp.paint(
        canvas,
        Offset(slot * group + (group - tp.width) / 2, plotH + 4),
      );
    }
  }

  Color _colorOf(ChartSeries s, int g) {
    final c = s.valueColors;
    return c != null && g < c.length ? c[g] : s.color;
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.labels != labels ||
      old.series != series ||
      old.rtl != rtl ||
      old.grid != grid;
}
