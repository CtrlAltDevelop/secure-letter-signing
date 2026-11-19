import 'package:material_ui/material_ui.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';

const _weekdayLetters = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
const _fridayWeekDay = 7; // Jalali.weekDay: Saturday = 1 ... Friday = 7

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _two(int n) => n.toString().padLeft(2, '0');

/// A month grid in the Persian calendar: Saturday first, Friday marked as weekend, month and
/// year navigation, today ring, optional [firstDate]/[lastDate] limits. Reports local midnight.
class JalaliCalendar extends StatefulWidget {
  const JalaliCalendar({
    super.key,
    required this.onChanged,
    this.selected,
    this.firstDate,
    this.lastDate,
  });

  final DateTime? selected;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final ValueChanged<DateTime> onChanged;

  @override
  State<JalaliCalendar> createState() => _JalaliCalendarState();
}

class _JalaliCalendarState extends State<JalaliCalendar> {
  late Jalali _month = _firstOfMonth(
    toJalali(widget.selected ?? DateTime.now()),
  );
  late DateTime? _selected = widget.selected == null
      ? null
      : _dateOnly(widget.selected!);

  static Jalali _firstOfMonth(Jalali j) => Jalali(j.year, j.month, 1);

  DateTime? get _min =>
      widget.firstDate == null ? null : _dateOnly(widget.firstDate!);
  DateTime? get _max =>
      widget.lastDate == null ? null : _dateOnly(widget.lastDate!);

  bool _allowed(Jalali j) {
    final d = j.toDateTime();
    return !(_min?.isAfter(d) ?? false) && !(_max?.isBefore(d) ?? false);
  }

  Jalali _shift(Jalali from, int months) {
    final total = from.year * 12 + (from.month - 1) + months;
    return Jalali(total ~/ 12, total % 12 + 1, 1);
  }

  /// A month can be shown when at least one of its days is allowed.
  bool _canShow(Jalali month) =>
      _allowed(month) || _allowed(month.copy(day: month.monthLength));

  void _go(int months) {
    final next = _shift(_month, months);
    if (_canShow(next)) setState(() => _month = next);
  }

  void _pick(Jalali day) {
    final date = day.toDateTime();
    setState(() => _selected = date);
    widget.onChanged(date);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(context),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (i, letter) in _weekdayLetters.indexed)
              Expanded(
                child: Center(child: _weekdayLabel(context, i + 1, letter)),
              ),
          ],
        ),
        for (final week in _weeks())
          Row(children: [for (final day in week) _cell(context, day)]),
      ],
    );
  }

  Widget _weekdayLabel(BuildContext context, int weekDay, String letter) {
    final theme = Theme.of(context);
    return Text(
      letter,
      style: theme.textTheme.labelMedium?.copyWith(
        color: weekDay == _fridayWeekDay ? theme.colorScheme.error : null,
      ),
    );
  }

  Widget _header(BuildContext context) {
    final canPrev = _canShow(_shift(_month, -1));
    final canNext = _canShow(_shift(_month, 1));
    return Row(
      children: [
        IconButton(
          key: const Key('jalali-prev-year'),
          icon: const Icon(Icons.keyboard_double_arrow_left),
          onPressed: canPrev ? () => _go(-12) : null,
        ),
        IconButton(
          key: const Key('jalali-prev-month'),
          icon: const Icon(Icons.chevron_left),
          onPressed: canPrev ? () => _go(-1) : null,
        ),
        Expanded(
          child: Text(
            '${jalaliMonthNames[_month.month - 1]} '
            '${toPersianDigits(_month.year)}',
            key: const Key('jalali-title'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          key: const Key('jalali-next-month'),
          icon: const Icon(Icons.chevron_right),
          onPressed: canNext ? () => _go(1) : null,
        ),
        IconButton(
          key: const Key('jalali-next-year'),
          icon: const Icon(Icons.keyboard_double_arrow_right),
          onPressed: canNext ? () => _go(12) : null,
        ),
      ],
    );
  }

  /// The month as rows of 7 cells (null = padding), Saturday first.
  List<List<Jalali?>> _weeks() {
    final lead = _month.weekDay - 1;
    final cells = <Jalali?>[
      for (var i = 0; i < lead; i++) null,
      for (var d = 1; d <= _month.monthLength; d++) _month.copy(day: d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return [for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7)];
  }

  Widget _cell(BuildContext context, Jalali? day) {
    if (day == null) return const Expanded(child: SizedBox(height: 44));
    final scheme = Theme.of(context).colorScheme;
    final date = day.toDateTime();
    final isSelected = _selected == date;
    final isToday = _dateOnly(DateTime.now()) == date;
    final allowed = _allowed(day);
    final color = isSelected
        ? scheme.onPrimary
        : day.weekDay == _fridayWeekDay
        ? scheme.error
        : scheme.onSurface;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: InkWell(
          key: Key(
            'jalali-day-${day.year}-${_two(day.month)}-${_two(day.day)}',
          ),
          customBorder: const CircleBorder(),
          onTap: allowed ? () => _pick(day) : null,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? scheme.primary : null,
              border: isToday && !isSelected
                  ? Border.all(color: scheme.primary)
                  : null,
            ),
            child: Text(
              toPersianDigits(day.day),
              style: TextStyle(
                color: allowed ? color : color.withValues(alpha: 0.3),
                fontWeight: isToday ? FontWeight.w700 : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog with a [JalaliCalendar]; with [withTime] a Material time picker follows.
/// Returns the chosen local [DateTime] (midnight unless [withTime]) or null when cancelled.
Future<DateTime?> showJalaliDatePicker(
  BuildContext context, {
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  bool withTime = false,
}) async {
  final date = await showDialog<DateTime>(
    context: context,
    builder: (_) => _JalaliPickerDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
  if (date == null || !withTime || !context.mounted) return date;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initialDate ?? DateTime.now()),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

class _JalaliPickerDialog extends StatefulWidget {
  const _JalaliPickerDialog({this.initialDate, this.firstDate, this.lastDate});
  final DateTime? initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  State<_JalaliPickerDialog> createState() => _JalaliPickerDialogState();
}

class _JalaliPickerDialogState extends State<_JalaliPickerDialog> {
  late DateTime? _value = widget.initialDate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: JalaliCalendar(
            selected: widget.initialDate,
            firstDate: widget.firstDate,
            lastDate: widget.lastDate,
            onChanged: (d) => setState(() => _value = d),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.jalaliPickerCancel),
        ),
        FilledButton(
          key: const Key('jalali-confirm'),
          onPressed: _value == null
              ? null
              : () => Navigator.pop(context, _value),
          child: Text(l.jalaliPickerConfirm),
        ),
      ],
    );
  }
}
