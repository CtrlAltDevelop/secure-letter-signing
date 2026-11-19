import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/monitor/monitor_api.dart';
import 'package:letter_signing/monitor/monitor_env.dart';
import 'package:letter_signing/monitor/report_ui.dart';
import 'package:letter_signing/workspace/models.dart';

/// Meetings of the period with attendance and open resolutions; filter by project title.
class MeetingsTab extends StatefulWidget {
  const MeetingsTab({super.key, required this.env, required this.period});
  final MonitorEnv env;
  final MonitorPeriod period;

  @override
  State<MeetingsTab> createState() => _MeetingsTabState();
}

class _MeetingsTabState extends State<MeetingsTab> {
  String _project = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            key: const ValueKey('meetings-project'),
            decoration: InputDecoration(
              labelText: l.monMeetingProjectFilter,
              isDense: true,
              prefixIcon: const Icon(Icons.search),
            ),
            onSubmitted: (v) => setState(() => _project = v.trim()),
          ),
        ),
        Expanded(
          child: ReportView(
            key: ValueKey('meetings-${widget.period.query()}-$_project'),
            load: () =>
                widget.env.api.meetings(widget.period, project: _project),
            builder: (context, data) => ReportPage(
              children: [
                StatWrap([
                  StatTile(l.monTotal, data['total']),
                  for (final e in asMap(data['by_status']).entries)
                    StatTile(e.key, e.value),
                ]),
                for (final m in asMapList(data['meetings']))
                  ListTile(
                    dense: true,
                    title: Text(asString(m['title'])),
                    subtitle: Text(
                      [
                        dateOf(m['starts_at']),
                        asString(m['project_name']),
                      ].where((s) => s.isNotEmpty).join(' | '),
                    ),
                    trailing: LtrText(
                      '${fmtNum(m['present'])}/${fmtNum(m['invited'])}'
                      '${intOf(m['open_resolutions']) > 0 ? '  !${fmtNum(m['open_resolutions'])}' : ''}',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
