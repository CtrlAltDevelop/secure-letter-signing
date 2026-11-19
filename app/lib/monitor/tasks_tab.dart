import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/monitor/monitor_api.dart';
import 'package:letter_signing/monitor/monitor_env.dart';
import 'package:letter_signing/monitor/report_ui.dart';
import 'package:letter_signing/monitor/tasks_print.dart';
import 'package:letter_signing/workspace/models.dart';

/// Status counts and the overdue report (who, what, how late) with project / label / person /
/// customer filters and a printable list.
class TasksTab extends StatefulWidget {
  const TasksTab({super.key, required this.env});
  final MonitorEnv env;

  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  String _project = '';
  int? _label;
  int? _person;
  String _customer = '';
  List<Map<String, dynamic>> _projects = const [];
  List<Map<String, dynamic>> _customers = const [];
  List<LabelInfo> _labels = const [];
  List<UserRef> _people = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadOptions());
  }

  Future<List<T>> _safe<T>(Future<List<T>> Function() f) async {
    try {
      return await f();
    } on Object {
      return <T>[];
    }
  }

  Future<void> _loadOptions() async {
    final api = widget.env.api;
    final results = await Future.wait([
      _safe(
        () async => asMapList((await api.projects('last_done'))['projects']),
      ),
      _safe(
        () async => asMapList(
          (await api.customers(const MonitorPeriod()))['customers'],
        ),
      ),
      _safe(api.workspace.labels),
      _safe(widget.env.directory ?? () async => <UserRef>[]),
    ]);
    if (!mounted) return;
    setState(() {
      _projects = results[0] as List<Map<String, dynamic>>;
      _customers = results[1] as List<Map<String, dynamic>>;
      _labels = [
        for (final x in results[2] as List<LabelInfo>)
          if (x.active) x,
      ];
      _people = results[3] as List<UserRef>;
    });
  }

  Widget _dropdown<T>(
    String key,
    String label,
    T value,
    Map<T, String> items,
    ValueChanged<T> on,
  ) => SizedBox(
    width: 160,
    child: DropdownButtonFormField<T>(
      key: ValueKey(key),
      isExpanded: true,
      initialValue: items.containsKey(value) ? value : items.keys.first,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: [
        for (final e in items.entries)
          DropdownMenuItem(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        if (v is T) on(v);
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final all = l.monFilterAll;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _dropdown<String>('f-project', l.monFilterProject, _project, {
                '': all,
                'none': l.monFilterNoProject,
                for (final p in _projects)
                  asString(p['id']): asString(p['name']),
              }, (v) => setState(() => _project = v)),
              _dropdown<int>('f-label', l.monFilterLabel, _label ?? 0, {
                0: all,
                for (final x in _labels) x.id: x.name,
              }, (v) => setState(() => _label = v == 0 ? null : v)),
              _dropdown<int>('f-person', l.monFilterPerson, _person ?? 0, {
                0: all,
                for (final u in _people) u.id: u.displayName,
              }, (v) => setState(() => _person = v == 0 ? null : v)),
              _dropdown<String>('f-customer', l.monFilterCustomer, _customer, {
                '': all,
                for (final c in _customers)
                  asString(c['id']): asString(c['name']),
              }, (v) => setState(() => _customer = v)),
              OutlinedButton.icon(
                key: const ValueKey('tasks-print'),
                icon: const Icon(Icons.print_outlined),
                label: Text(l.monPrint),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TasksPrintScreen(
                      env: widget.env,
                      project: _project,
                      label: _label,
                      person: _person,
                      customer: _customer,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReportView(
            key: ValueKey('tasks-$_project-$_label-$_person-$_customer'),
            load: () => widget.env.api.tasks(
              project: _project,
              label: _label,
              person: _person,
              customer: _customer,
            ),
            builder: (context, data) {
              final by = asMap(data['by_status']);
              return ReportPage(
                children: [
                  StatWrap([
                    StatTile(l.monStatusOpen, by['open']),
                    StatTile(l.monStatusAwaiting, by['awaiting_approval']),
                    StatTile(l.monStatusDone, by['done']),
                    StatTile(l.monStatusCancelled, by['cancelled']),
                    StatTile(l.monOverdue, data['overdue_total'], warn: true),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    l.monOverdueReport,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  for (final t in asMapList(data['overdue']))
                    ListTile(
                      dense: true,
                      title: Text(asString(t['title'])),
                      subtitle: Text(
                        [
                          for (final o in asMapList(t['owners'])) personName(o),
                          asString(t['project_name']),
                        ].where((s) => s.isNotEmpty).join(' | '),
                      ),
                      trailing: Text(
                        '${fmtNum(t['days_late'])} ${l.monDays}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
