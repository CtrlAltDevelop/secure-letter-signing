import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/calendar/calendar_controller.dart';
import 'package:letter_signing/calendar/calendar_env.dart';
import 'package:letter_signing/calendar/calendar_filter_sheet.dart';
import 'package:letter_signing/calendar/colleague_tasks_screen.dart';
import 'package:letter_signing/calendar/models.dart';
import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/projects/models.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/open_target.dart';

const _weekdayLetters = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

/// Work calendar: Jalali month or week of my tasks, meetings, reminders and project dates with
/// the server's holidays marked. [projectId] makes it the calendar of one project; users with
/// `monitor.view` can switch to the shared team calendar and open a colleague's inbox.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.env,
    this.projectId,
    this.embedded = false,
    this.today,
  });

  final CalendarEnv env;
  final String? projectId;
  final bool embedded;

  /// Clock for tests.
  final DateTime? today;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final CalendarController _c = CalendarController(
    widget.env,
    filter: CalendarFilter(projectId: widget.projectId),
    today: widget.today,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_c.load());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _filters() async {
    final f = await showCalendarFilterSheet(
      context,
      widget.env,
      _c.filter,
      fixedProject: widget.projectId != null,
    );
    if (f != null) await _c.setFilter(f);
  }

  void _openColleagues() => unawaited(
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ColleagueTasksScreen(env: widget.env),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final body = ListenableBuilder(
      listenable: _c,
      builder: (context, _) => Column(
        children: [
          _toolbar(l),
          Expanded(child: _content(context, l)),
        ],
      ),
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text(l.calendarTitle)),
      body: body,
    );
  }

  Widget _toolbar(AppLocalizations l) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Row(
      children: [
        SegmentedButton<bool>(
          key: const ValueKey('cal-mode'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: false, label: Text(l.calendarMonth)),
            ButtonSegment(value: true, label: Text(l.calendarWeek)),
          ],
          selected: {_c.week},
          onSelectionChanged: (s) => unawaited(_c.setWeek(week: s.first)),
        ),
        const Spacer(),
        if (widget.env.canMonitor && widget.projectId == null) ...[
          FilterChip(
            key: const ValueKey('cal-team'),
            label: Text(l.calendarTeam),
            selected: _c.filter.team,
            onSelected: (v) =>
                unawaited(_c.setFilter(_c.filter.copyWith(team: v))),
          ),
          IconButton(
            key: const ValueKey('cal-colleagues'),
            tooltip: l.calendarColleagues,
            icon: const Icon(Icons.groups_outlined),
            onPressed: _openColleagues,
          ),
        ],
        IconButton(
          key: const ValueKey('cal-filter'),
          tooltip: l.calendarFilters,
          icon: Badge(
            isLabelVisible: _c.filter.isActive,
            smallSize: 8,
            child: const Icon(Icons.filter_list),
          ),
          onPressed: () => unawaited(_filters()),
        ),
      ],
    ),
  );

  Widget _content(BuildContext context, AppLocalizations l) {
    if (_c.error != null && !_c.loaded) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: l.calendarLoadFailed,
        action: OutlinedButton(
          onPressed: () => unawaited(_c.load()),
          child: Text(l.commonRetry),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _header(context),
        _weekdays(context),
        ..._grid(context),
        if (_c.loading) const LinearProgressIndicator(),
        const SizedBox(height: 12),
        ..._day(context, l),
      ],
    );
  }

  Widget _header(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final title = _c.week
        ? '${formatJalaliDate(_c.weekStart)} - ${formatJalaliDate(_c.weekStart.add(const Duration(days: 6)))}'
        : _c.month.title;
    return Row(
      children: [
        IconButton(
          key: const ValueKey('cal-prev'),
          icon: Icon(rtl ? Icons.chevron_right : Icons.chevron_left),
          onPressed: () => unawaited(_c.shift(-1)),
        ),
        Expanded(
          child: Text(
            title,
            key: const ValueKey('cal-title'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          key: const ValueKey('cal-next'),
          icon: Icon(rtl ? Icons.chevron_left : Icons.chevron_right),
          onPressed: () => unawaited(_c.shift(1)),
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

  List<Widget> _grid(BuildContext context) {
    if (_c.week) {
      final s = _c.weekStart;
      return [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              _cell(context, DateTime(s.year, s.month, s.day + i)),
          ],
        ),
      ];
    }
    final m = _c.month;
    return [
      for (final week in m.weeks())
        Row(
          children: [
            for (final d in week)
              d == null
                  ? const Expanded(child: SizedBox(height: 52))
                  : _cell(context, m.day(d)),
          ],
        ),
    ];
  }

  Widget _cell(BuildContext context, DateTime date) {
    final scheme = Theme.of(context).colorScheme;
    final key = dayKey(date);
    final count = _c.byDay[key]?.length ?? 0;
    final holiday = _c.holidaysByDay.containsKey(key);
    // The server's `weekend` is the constant Friday; its index base is ambiguous, so use Friday.
    final friday = date.weekday == DateTime.friday;
    final selected = dayKey(_c.selected) == key;
    final today = dayKey(widget.today ?? DateTime.now()) == key;
    final color = selected
        ? scheme.onPrimary
        : (holiday || friday)
        ? scheme.error
        : scheme.onSurface;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: InkWell(
          key: ValueKey('cal-day-$key'),
          borderRadius: BorderRadius.circular(10),
          onTap: () => _c.select(date),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: selected
                  ? scheme.primary
                  : holiday
                  ? scheme.error.withValues(alpha: 0.10)
                  : null,
              border: today && !selected
                  ? Border.all(color: scheme.primary)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  toPersianDigits(toJalali(date).day),
                  style: TextStyle(
                    color: color,
                    fontWeight: today ? FontWeight.w700 : null,
                  ),
                ),
                if (count > 0)
                  Text(
                    toPersianDigits(count),
                    key: ValueKey('cal-count-$key'),
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

  List<Widget> _day(BuildContext context, AppLocalizations l) {
    final items = _c.selectedItems;
    return [
      Text(
        formatJalaliLong(_c.selected),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      for (final h in _c.selectedHolidays)
        ListTile(
          key: ValueKey('cal-holiday-${h.title}'),
          dense: true,
          leading: Icon(
            Icons.celebration_outlined,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(h.title),
        ),
      if (items.isEmpty && _c.selectedHolidays.isEmpty)
        Text(l.calendarDayNothing),
      for (final i in items) _itemTile(context, i, l),
    ];
  }

  OpenTarget? _target(CalendarItem i) {
    final module = switch (i.kind) {
      'task' => 'tasks',
      'meeting' => 'meetings',
      'project' => 'projects',
      _ => null,
    };
    return module == null
        ? null
        : OpenTarget(
            module: module,
            kind: i.kind,
            id: i.id,
            subjectId: i.subjectId,
          );
  }

  Widget _itemTile(BuildContext context, CalendarItem i, AppLocalizations l) {
    final target = _target(i);
    final time = i.allDay ? l.calendarAllDay : formatJalaliTime(i.start);
    return ListTile(
      key: ValueKey('cal-item-${i.kind}-${i.id}'),
      leading: CircleAvatar(
        radius: 6,
        backgroundColor: i.color == 0 ? null : projectColor(i.color),
      ),
      title: Text(
        i.title,
        style: i.done
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: Text(
        [
          switch (i.kind) {
            'task' => l.calendarKindTask,
            'meeting' => l.calendarKindMeeting,
            'reminder' => l.calendarKindReminder,
            _ => l.calendarKindProject,
          },
          time,
          if (i.projectName.isNotEmpty) i.projectName,
        ].join(' | '),
      ),
      onTap: target == null
          ? null
          : () => unawaited(widget.env.open(context, target)),
    );
  }
}
