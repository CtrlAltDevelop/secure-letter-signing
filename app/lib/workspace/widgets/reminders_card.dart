import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/widgets/jalali_date_field.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// 'روزانه', 'هفتگی (شنبه، دوشنبه)', 'ماهانه (روز ۵)'.
String reminderRuleText(
  AppLocalizations l,
  ReminderRule rule,
) => switch (rule.freq) {
  ReminderRule.weekly =>
    '${l.reminderWeekly} (${[for (final d in rule.weekdays)
      if (d >= 0 && d < 7) jalaliWeekdayNames[d]].join('، ')})',
  ReminderRule.monthly =>
    '${l.reminderMonthly} (${l.reminderMonthDay(toPersianDigits(rule.day ?? 1))})',
  _ => l.reminderDaily,
};

/// My reminders on one subject (a task or project): list, add with a Jalali date and time and
/// an optional repeat, deactivate.
class RemindersCard extends StatefulWidget {
  const RemindersCard({super.key, required this.api, required this.subjectId});

  final WorkspaceApi api;
  final String subjectId;

  @override
  State<RemindersCard> createState() => _RemindersCardState();
}

class _RemindersCardState extends State<RemindersCard> {
  List<ReminderInfo> _items = const [];
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final items = await widget.api.reminders(widget.subjectId);
      if (mounted) setState(() => _items = items);
    } on NotFoundException {
      if (mounted) setState(() => _unavailable = true);
    } on Object {
      // Keep what is shown; reminders are secondary.
    }
  }

  void _snack(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _add() async {
    final picked = await showReminderDialog(context);
    if (picked == null) return;
    try {
      await widget.api.addReminder(
        widget.subjectId,
        at: picked.at,
        rule: picked.rule,
      );
    } on Object catch (e) {
      _snack('$e');
      return;
    }
    await _load();
  }

  Future<void> _remove(ReminderInfo r) async {
    try {
      await widget.api.deactivateReminder(r.id);
    } on Object catch (e) {
      _snack('$e');
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_unavailable) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.remindersTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton.icon(
                key: const ValueKey('reminder-add'),
                onPressed: () => unawaited(_add()),
                icon: const Icon(Icons.add_alert_outlined, size: 18),
                label: Text(l.reminderAdd),
              ),
            ],
          ),
          if (_items.isEmpty) Text(l.remindersEmpty),
          for (final r in _items) _row(l, r),
        ],
      ),
    );
  }

  Widget _row(AppLocalizations l, ReminderInfo r) {
    final rule = r.rule;
    return ListTile(
      key: ValueKey('reminder-${r.id}'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.alarm),
      title: Text(formatJalaliDateTime(r.at)),
      subtitle: rule == null ? null : Text(reminderRuleText(l, rule)),
      trailing: IconButton(
        key: ValueKey('reminder-remove-${r.id}'),
        tooltip: l.reminderRemove,
        icon: const Icon(Icons.close),
        onPressed: () => unawaited(_remove(r)),
      ),
    );
  }
}

/// A reminder the user composed: when, and how it repeats (null = once).
typedef ReminderDraft = ({DateTime at, ReminderRule? rule});

/// Asks for the date and time and the repeat. Resolves to null when cancelled.
Future<ReminderDraft?> showReminderDialog(
  BuildContext context, {
  DateTime? now,
}) => showDialog<ReminderDraft>(
  context: context,
  builder: (_) => _ReminderDialog(now: now ?? DateTime.now()),
);

class _ReminderDialog extends StatefulWidget {
  const _ReminderDialog({required this.now});
  final DateTime now;

  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  DateTime? _at;
  String? _freq;
  final Set<int> _weekdays = {};
  bool _submitted = false;

  bool get _past => _at != null && !_at!.isAfter(widget.now);

  void _setFreq(String? freq) => setState(() {
    _freq = freq;
    if (freq == ReminderRule.weekly && _weekdays.isEmpty && _at != null) {
      _weekdays.add(toJalali(_at!).weekDay - 1);
    }
  });

  ReminderRule? _rule() {
    final at = _at;
    return switch (_freq) {
      ReminderRule.daily => const ReminderRule(),
      ReminderRule.weekly => ReminderRule(
        freq: ReminderRule.weekly,
        weekdays: [..._weekdays]..sort(),
      ),
      ReminderRule.monthly when at != null => ReminderRule(
        freq: ReminderRule.monthly,
        day: toJalali(at).day,
      ),
      _ => null,
    };
  }

  void _save() {
    setState(() => _submitted = true);
    final at = _at;
    if (at == null || _past) return;
    if (_freq == ReminderRule.weekly && _weekdays.isEmpty) return;
    Navigator.pop(context, (at: at, rule: _rule()));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final error = _submitted && (_at == null || _past)
        ? l.reminderDateRequired
        : null;
    return AlertDialog(
      title: Text(l.reminderAdd),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            JalaliDateField(
              key: const ValueKey('reminder-date'),
              label: l.reminderWhen,
              value: _at,
              withTime: true,
              clearable: false,
              firstDate: widget.now,
              onChanged: (v) => setState(() => _at = v),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              l.reminderRepeat,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            _repeatChips(l),
            if (_freq == ReminderRule.weekly) _weekdayChips(l),
            if (_freq == ReminderRule.monthly && _at != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l.reminderMonthDay(toPersianDigits(toJalali(_at!).day)),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('reminder-save'),
          onPressed: _save,
          child: Text(l.commonSave),
        ),
      ],
    );
  }

  Widget _repeatChips(AppLocalizations l) {
    final options = <(String?, String)>[
      (null, l.reminderOnce),
      (ReminderRule.daily, l.reminderDaily),
      (ReminderRule.weekly, l.reminderWeekly),
      (ReminderRule.monthly, l.reminderMonthly),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final (freq, label) in options)
          ChoiceChip(
            key: ValueKey('repeat-${freq ?? 'none'}'),
            label: Text(label),
            selected: _freq == freq,
            onSelected: (_) => _setFreq(freq),
          ),
      ],
    );
  }

  Widget _weekdayChips(AppLocalizations l) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (var d = 0; d < 7; d++)
          FilterChip(
            key: ValueKey('weekday-$d'),
            label: Text(jalaliWeekdayNames[d]),
            visualDensity: VisualDensity.compact,
            selected: _weekdays.contains(d),
            onSelected: (on) => setState(() {
              if (on) {
                _weekdays.add(d);
              } else {
                _weekdays.remove(d);
              }
            }),
          ),
      ],
    ),
  );
}
