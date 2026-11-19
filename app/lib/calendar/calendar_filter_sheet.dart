import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/calendar/calendar_env.dart';
import 'package:letter_signing/calendar/models.dart';
import 'package:letter_signing/crm/models.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/projects/models.dart';
import 'package:letter_signing/workspace/models.dart';

/// Lookups for the filter sheet; each failing one just yields an empty list.
class _Lookups {
  const _Lookups(this.projects, this.labels, this.people, this.customers);
  final List<ProjectBrief> projects;
  final List<LabelInfo> labels;
  final List<UserRef> people;
  final List<Customer> customers;
}

Future<List<T>> _safe<T>(Future<List<T>> Function() f) async {
  try {
    return await f();
  } on Object {
    return <T>[];
  }
}

Future<_Lookups> _load(CalendarEnv env) async {
  final crm = env.crm;
  final r = await Future.wait([
    _safe(() => env.projects.list()),
    _safe(env.tasks.labels),
    _safe(env.tasks.directory),
    _safe(
      () async => crm == null ? <Customer>[] : crm.list(const CustomerFilter()),
    ),
  ]);
  return _Lookups(
    r[0] as List<ProjectBrief>,
    r[1] as List<LabelInfo>,
    r[2] as List<UserRef>,
    r[3] as List<Customer>,
  );
}

/// Bottom sheet with project, label, status, person and customer filters; returns the new
/// filter, or null when dismissed. [fixedProject] hides the project choice.
Future<CalendarFilter?> showCalendarFilterSheet(
  BuildContext context,
  CalendarEnv env,
  CalendarFilter current, {
  bool fixedProject = false,
}) => showModalBottomSheet<CalendarFilter>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) =>
      _Sheet(env: env, current: current, fixedProject: fixedProject),
);

class _Sheet extends StatefulWidget {
  const _Sheet({
    required this.env,
    required this.current,
    required this.fixedProject,
  });
  final CalendarEnv env;
  final CalendarFilter current;
  final bool fixedProject;

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  late CalendarFilter _f = widget.current;
  late final Future<_Lookups> _lookups = _load(widget.env);

  Widget _drop<T>(
    String label,
    T? value,
    List<(T, String)> options,
    String allLabel,
    ValueChanged<T?> onChanged,
    Key key,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<T?>(
      key: key,
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem<T?>(value: null, child: Text(allLabel)),
        for (final (v, t) in options)
          DropdownMenuItem<T?>(value: v, child: Text(t)),
      ],
      onChanged: onChanged,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: FutureBuilder<_Lookups>(
          future: _lookups,
          builder: (context, snap) {
            final d = snap.data;
            if (d == null) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!widget.fixedProject)
                    _drop<String>(
                      l.calendarFilterProject,
                      _f.projectId,
                      [for (final p in d.projects) (p.id, p.name)],
                      l.calendarFilterAll,
                      (v) => setState(() => _f = _f.copyWith(projectId: v)),
                      const ValueKey('flt-project'),
                    ),
                  _drop<int>(
                    l.calendarFilterLabel,
                    _f.labelId,
                    [for (final x in d.labels) (x.id, x.name)],
                    l.calendarFilterAll,
                    (v) => setState(() => _f = _f.copyWith(labelId: v)),
                    const ValueKey('flt-label'),
                  ),
                  _drop<int>(
                    l.calendarFilterPerson,
                    _f.ownerId,
                    [for (final u in d.people) (u.id, u.displayName)],
                    l.calendarFilterAll,
                    (v) => setState(() => _f = _f.copyWith(ownerId: v)),
                    const ValueKey('flt-person'),
                  ),
                  if (d.customers.isNotEmpty)
                    _drop<String>(
                      l.calendarFilterCustomer,
                      _f.customerId,
                      [for (final c in d.customers) (c.id, c.name)],
                      l.calendarFilterAll,
                      (v) => setState(() => _f = _f.copyWith(customerId: v)),
                      const ValueKey('flt-customer'),
                    ),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: CalendarStatus.all,
                        label: Text(l.calendarStatusAll),
                      ),
                      ButtonSegment(
                        value: CalendarStatus.open,
                        label: Text(l.calendarStatusOpen),
                      ),
                      ButtonSegment(
                        value: CalendarStatus.done,
                        label: Text(l.calendarStatusDone),
                      ),
                    ],
                    selected: {_f.status},
                    onSelectionChanged: (s) =>
                        setState(() => _f = _f.copyWith(status: s.first)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(
                          context,
                          CalendarFilter(
                            team: _f.team,
                            projectId: widget.fixedProject
                                ? _f.projectId
                                : null,
                          ),
                        ),
                        child: Text(l.calendarFilterReset),
                      ),
                      const Spacer(),
                      FilledButton(
                        key: const ValueKey('flt-apply'),
                        onPressed: () => Navigator.pop(context, _f),
                        child: Text(l.calendarFilterApply),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
