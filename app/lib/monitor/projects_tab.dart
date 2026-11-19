import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/monitor/monitor_env.dart';
import 'package:letter_signing/monitor/report_ui.dart';
import 'package:letter_signing/workspace/models.dart';

/// Per-project and per-group report; sort by last done task, overdue or completed.
class ProjectsTab extends StatefulWidget {
  const ProjectsTab({super.key, required this.env});
  final MonitorEnv env;

  @override
  State<ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends State<ProjectsTab> {
  String _sort = 'last_done';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sorts = {
      'last_done': l.monSortLastDone,
      'most_overdue': l.monSortMostOverdue,
      'least_overdue': l.monSortLeastOverdue,
      'completed': l.monSortCompleted,
    };
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SortMenu(
            key: const ValueKey('projects-sort'),
            value: _sort,
            options: sorts,
            onChanged: (v) => setState(() => _sort = v),
          ),
        ),
        Expanded(
          child: ReportView(
            key: ValueKey('projects-$_sort'),
            load: () => widget.env.api.projects(_sort),
            builder: (context, data) => ReportPage(
              children: [
                Text(
                  l.monGroups,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (final g in asMapList(data['groups']))
                  _row(
                    context,
                    asString(g['group_name'], l.monNoGroup),
                    '${fmtNum(g['projects'])} ${l.monProjectsCount}',
                    g,
                  ),
                const Divider(),
                Text(
                  l.monProjectsTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (final p in asMapList(data['projects']))
                  _row(
                    context,
                    asString(p['name']),
                    asString(p['group_name']),
                    p,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String title,
    String sub,
    Map<String, dynamic> m,
  ) {
    final l = AppLocalizations.of(context);
    final last = dateOf(m['last_done_at']);
    return ListTile(
      dense: true,
      title: Text(title),
      subtitle: Text(
        [sub, if (last.isNotEmpty) last].where((s) => s.isNotEmpty).join(' | '),
      ),
      trailing: LtrText(
        '${fmtNum(m['tasks_open'])} / ${fmtNum(m['tasks_done'])} / ${fmtNum(m['tasks_overdue'])}',
        style: TextStyle(
          color: intOf(m['tasks_overdue']) > 0
              ? Theme.of(context).colorScheme.error
              : null,
        ),
      ),
      onTap: null,
      leading: Tooltip(
        message: '${l.monOpenTasks} / ${l.monDone} / ${l.monOverdue}',
        child: const Icon(Icons.folder_outlined),
      ),
    );
  }
}
