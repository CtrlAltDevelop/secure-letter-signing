import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/jalali/jalali_picker.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/monitor/monitor_api.dart';

/// Period presets, a custom Jalali range and the bucket size.
class PeriodBar extends StatelessWidget {
  const PeriodBar({
    super.key,
    required this.period,
    required this.onChanged,
    this.showBucket = true,
  });

  final MonitorPeriod period;
  final ValueChanged<MonitorPeriod> onChanged;
  final bool showBucket;

  Future<void> _custom(BuildContext context) async {
    final now = DateTime.now();
    final from = await showJalaliDatePicker(
      context,
      initialDate: period.from ?? now.subtract(const Duration(days: 29)),
      firstDate: DateTime(now.year - 3),
      lastDate: now,
    );
    if (from == null || !context.mounted) return;
    final to = await showJalaliDatePicker(
      context,
      initialDate: period.to ?? now,
      firstDate: from,
      lastDate: now,
    );
    if (to != null) onChanged(period.copyWith(from: from, to: to));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final presets = {
      'week': l.monPeriodWeek,
      'month': l.monPeriodMonth,
      'quarter': l.monPeriodQuarter,
      'year': l.monPeriodYear,
    };
    final buckets = {
      'day': l.monBucketDay,
      'week': l.monBucketWeek,
      'month': l.monBucketMonth,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final e in presets.entries)
            ChoiceChip(
              key: ValueKey('period-${e.key}'),
              label: Text(e.value),
              selected: !period.custom && period.preset == e.key,
              onSelected: (_) => onChanged(period.copyWith(preset: e.key)),
            ),
          ChoiceChip(
            key: const ValueKey('period-custom'),
            label: Text(
              period.custom
                  ? toPersianDigits(
                      '${formatJalaliDate(period.from!)} - ${formatJalaliDate(period.to!)}',
                    )
                  : l.monPeriodCustom,
            ),
            selected: period.custom,
            onSelected: (_) => unawaited(_custom(context)),
          ),
          if (showBucket)
            for (final e in buckets.entries)
              ChoiceChip(
                key: ValueKey('bucket-${e.key}'),
                label: Text(e.value),
                selected: period.bucket == e.key,
                onSelected: (_) => onChanged(period.copyWith(bucket: e.key)),
              ),
        ],
      ),
    );
  }
}
