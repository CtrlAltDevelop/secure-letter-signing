import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';

/// A small ring with the percentage in the middle. [value] is 0..100.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 40,
    this.strokeWidth = 4,
  });

  final int value;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percent = value.clamp(0, 100);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: percent / 100,
              strokeWidth: strokeWidth,
              backgroundColor: scheme.onSurface.withValues(alpha: 0.10),
              color: percent >= 100 ? scheme.tertiary : scheme.primary,
            ),
          ),
          Text(
            toPersianDigits(percent),
            style: TextStyle(
              fontSize: size * 0.28,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
