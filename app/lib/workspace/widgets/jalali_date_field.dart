import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/jalali/jalali_picker.dart';
import 'package:letter_signing/l10n/app_localizations.dart';

/// Read-only form field that shows a date in Jalali and opens [showJalaliDatePicker].
/// [value] and [onChanged] carry plain [DateTime]s; convert to UTC ISO only when sending.
class JalaliDateField extends StatelessWidget {
  const JalaliDateField({
    super.key,
    required this.onChanged,
    this.value,
    this.label,
    this.firstDate,
    this.lastDate,
    this.withTime = false,
    this.clearable = true,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String? label;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool withTime;
  final bool clearable;

  Future<void> _open(BuildContext context) async {
    final picked = await showJalaliDatePicker(
      context,
      initialDate: value,
      firstDate: firstDate,
      lastDate: lastDate,
      withTime: withTime,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final current = value;
    final text = current == null
        ? l.jalaliFieldHint
        : withTime
        ? formatJalaliDateTime(current)
        : formatJalaliDate(current);
    return InkWell(
      onTap: () => unawaited(_open(context)),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_month_outlined),
          suffixIcon: clearable && current != null
              ? IconButton(
                  tooltip: l.jalaliFieldClear,
                  icon: const Icon(Icons.close),
                  onPressed: () => onChanged(null),
                )
              : null,
        ),
        child: Text(
          text,
          style: current == null
              ? TextStyle(color: Theme.of(context).hintColor)
              : null,
        ),
      ),
    );
  }
}
