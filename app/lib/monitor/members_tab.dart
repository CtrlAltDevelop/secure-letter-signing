import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/monitor/colleague_tasks_screen.dart';
import 'package:letter_signing/monitor/monitor_api.dart';
import 'package:letter_signing/monitor/monitor_env.dart';
import 'package:letter_signing/monitor/report_ui.dart';
import 'package:letter_signing/workspace/models.dart';

/// Opens a colleague's task inbox.
void openColleagueTasks(
  BuildContext context,
  MonitorEnv env,
  Map<String, dynamic> user,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => ColleagueTasksScreen(
      env: env,
      userId: intOf(user['id']),
      name: personName(user),
    ),
  ),
);

/// Per-person performance table with a sort menu.
class MembersTab extends StatefulWidget {
  const MembersTab({super.key, required this.env, required this.period});
  final MonitorEnv env;
  final MonitorPeriod period;

  @override
  State<MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<MembersTab> {
  String _sort = 'done';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sorts = {
      'done': l.monDone,
      'overdue': l.monOverdue,
      'activity': l.monSortActivity,
    };
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SortMenu(
            key: const ValueKey('members-sort'),
            value: _sort,
            options: sorts,
            onChanged: (v) => setState(() => _sort = v),
          ),
        ),
        Expanded(
          child: ReportView(
            key: ValueKey('members-${widget.period.query()}-$_sort'),
            load: () => widget.env.api.members(widget.period, _sort),
            builder: (context, data) => ReportPage(
              children: [
                for (final m in asMapList(data['members'])) _row(context, l, m),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    AppLocalizations l,
    Map<String, dynamic> m,
  ) {
    final t = asMap(m['tasks']);
    final parts = <String>[
      if (m['tasks'] != null) ...[
        '${l.monOnTime} ${fmtNum(t['on_time'])}',
        '${l.monLateDone} ${fmtNum(t['late'])}',
        '${l.monOverdue} ${fmtNum(t['overdue'])}',
        '${l.monAvgDelay} ${fmtNum(t['avg_delay_days'])}',
      ],
      if (m['messages'] != null) '${l.monMessages} ${fmtNum(m['messages'])}',
      if (m['letters_signed'] != null)
        '${l.monLettersSigned} ${fmtNum(m['letters_signed'])}',
      if (m['meetings_attended'] != null)
        '${l.monMeetingsAttended} ${fmtNum(m['meetings_attended'])}',
    ];
    final user = asMap(m['user']);
    return ListTile(
      key: ValueKey('member-${user['id']}'),
      dense: true,
      title: Text(personName(user)),
      subtitle: Text(parts.join('  |  ')),
      trailing: const Icon(Icons.chevron_left),
      onTap: () => openColleagueTasks(context, widget.env, user),
    );
  }
}

/// Last activity of every user; tap for their tasks, long-press for login / device history.
class OnlineTab extends StatefulWidget {
  const OnlineTab({super.key, required this.env});
  final MonitorEnv env;

  @override
  State<OnlineTab> createState() => _OnlineTabState();
}

class _OnlineTabState extends State<OnlineTab> {
  int? _history;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ReportView(
      key: ValueKey('online-$_history'),
      load: () => widget.env.api.online(historyOf: _history),
      builder: (context, data) => ReportPage(
        children: [
          for (final u in asMapList(data['users']))
            ListTile(
              key: ValueKey('online-${asMap(u['user'])['id']}'),
              dense: true,
              leading: Icon(
                Icons.circle,
                size: 12,
                color: u['online'] == true ? Colors.green : Colors.grey,
              ),
              title: Text(personName(u['user'])),
              subtitle: Text(
                '${l.monLastActive}: ${dateOf(u['last_active'], l.monNever)}',
              ),
              onTap: () =>
                  openColleagueTasks(context, widget.env, asMap(u['user'])),
              trailing: IconButton(
                key: ValueKey('history-${asMap(u['user'])['id']}'),
                tooltip: l.monHistory,
                icon: const Icon(Icons.history),
                onPressed: () =>
                    setState(() => _history = intOf(asMap(u['user'])['id'])),
              ),
            ),
          if (_history != null) ...[
            const Divider(),
            Text(l.monHistory, style: Theme.of(context).textTheme.titleSmall),
            for (final h in asMapList(data['history']))
              ListTile(
                dense: true,
                title: Text(
                  '${asString(h['device_name'])} (${asString(h['platform'])})',
                ),
                subtitle: Text(
                  '${dateOf(h['created_at'])}  -  ${dateOf(h['last_active'])}'
                  '${h['revoked'] == true ? '  ${l.monRevoked}' : ''}',
                ),
              ),
          ],
        ],
      ),
    );
  }
}
