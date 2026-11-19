import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/projects/project_views_controller.dart';
import 'package:letter_signing/tasks/task_card.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/workspace/models.dart';

const _weekdayLetters = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

/// Jalali month grid (Saturday first, Friday the weekend) showing how many tasks fall due on
/// each day; tapping a day lists its tasks below the grid.
class ProjectCalendarView extends StatelessWidget {
  const ProjectCalendarView({
    super.key,
    required this.controller,
    required this.onOpenTask,
    this.labels = const [],
    this.today,
  });

  final ProjectCalendarController controller;
  final ValueChanged<String> onOpenTask;
  final List<LabelInfo> labels;

  /// Clock for the today marker (tests).
  final DateTime? today;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Tokens.gap,
        8,
        Tokens.gap,
        24,
      ),
      children: [
        _header(context),
        const SizedBox(height: 8),
        _weekdays(context),
        for (final week in controller.month.weeks())
          Row(children: [for (final d in week) _cell(context, d)]),
        const SizedBox(height: 12),
        ..._selected(context),
      ],
    ),
  );

  Widget _header(BuildContext context) {
    final month = controller.month;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Row(
      children: [
        IconButton(
          key: const ValueKey('cal-prev'),
          icon: Icon(rtl ? Icons.chevron_right : Icons.chevron_left),
          onPressed: () => unawaited(controller.shift(-1)),
        ),
        Expanded(
          child: Text(
            month.title,
            key: const ValueKey('cal-title'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          key: const ValueKey('cal-next'),
          icon: Icon(rtl ? Icons.chevron_left : Icons.chevron_right),
          onPressed: () => unawaited(controller.shift(1)),
        ),
      ],
    );
  }

  Widget _weekdays(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (final (i, letter) in _weekdayLetters.indexed)
          Expanded(
            child: Center(
              child: Text(
                letter,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: i == 6 ? theme.colorScheme.error : null,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _cell(BuildContext context, int? day) {
    if (day == null) return const Expanded(child: SizedBox(height: 52));
    final scheme = Theme.of(context).colorScheme;
    final month = controller.month;
    final count = controller.byDay[day]?.length ?? 0;
    final selected = controller.selectedDay == day;
    final isToday = month.dayOf(today ?? DateTime.now()) == day;
    final color = selected
        ? scheme.onPrimary
        : month.isFriday(day)
        ? scheme.error
        : scheme.onSurface;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: InkWell(
          key: ValueKey('cal-day-$day'),
          borderRadius: BorderRadius.circular(10),
          onTap: () => controller.select(day),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: selected ? scheme.primary : null,
              border: isToday && !selected
                  ? Border.all(color: scheme.primary)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  toPersianDigits(day),
                  style: TextStyle(
                    color: color,
                    fontWeight: isToday ? FontWeight.w700 : null,
                  ),
                ),
                if (count > 0)
                  Text(
                    toPersianDigits(count),
                    key: ValueKey('cal-count-$day'),
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? scheme.onPrimary : scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _selected(BuildContext context) {
    final l = AppLocalizations.of(context);
    final day = controller.selectedDay;
    if (controller.loading && !controller.loaded) {
      return const [Center(child: CircularProgressIndicator())];
    }
    if (day == null) return [Text(l.calendarPickDay)];
    final tasks = controller.selectedTasks;
    final heading = formatJalaliLong(controller.month.day(day));
    return [
      Text(heading, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      if (tasks.isEmpty) Text(l.calendarDayEmpty),
      for (final t in tasks)
        Padding(
          key: ValueKey('cal-task-${t.id}'),
          padding: const EdgeInsets.only(bottom: 8),
          child: TaskCard(
            task: t,
            labels: labels,
            onTap: () => onOpenTask(t.id),
          ),
        ),
    ];
  }
}
