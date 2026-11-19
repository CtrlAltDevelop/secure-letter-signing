import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';

String two(int n) => n.toString().padLeft(2, '0');

/// Jalali date, e.g. `۱۴۰۵/۰۱/۰۱` (local time).
String fmtDate(DateTime d) => formatJalaliDate(d);

/// Jalali date and time, e.g. `۱۴۰۵/۰۱/۰۱ ۱۴:۰۵`.
String fmtDateTime(DateTime d) => formatJalaliDateTime(d);

String fmtSize(int bytes) => bytes >= 1024 * 1024
    ? '${toPersianDigits((bytes / (1024 * 1024)).toStringAsFixed(1))} MB'
    : '${toPersianDigits((bytes / 1024).ceil())} KB';

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+|@')).where((p) => p.isNotEmpty);
  final s = parts.take(2).map((p) => p[0].toUpperCase()).join();
  return s.isEmpty ? '?' : s;
}

IconData attachmentIcon(String contentType) => switch (contentType) {
  'application/pdf' => Icons.picture_as_pdf_outlined,
  final t when t.startsWith('image/') => Icons.image_outlined,
  _ => Icons.attach_file,
};

/// Round initials avatar; [tone] colours the ring (decision state).
class PersonAvatar extends StatelessWidget {
  const PersonAvatar(this.name, {super.key, this.color, this.size = 36});
  final String name;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withValues(alpha: 0.14),
        border: Border.all(color: c, width: 1.5),
      ),
      child: Text(
        initials(name),
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

/// Inline error banner with an optional retry.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Tokens.error.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(Tokens.radiusSmall),
      border: Border.all(color: Tokens.error.withValues(alpha: 0.4)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, color: Tokens.error, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

/// Pulsing placeholder rows shown while a list loads.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 5});
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Tokens.gap),
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(180, 16),
                  const SizedBox(height: 10),
                  bar(120, 12),
                  const SizedBox(height: 10),
                  bar(double.infinity, 6),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
