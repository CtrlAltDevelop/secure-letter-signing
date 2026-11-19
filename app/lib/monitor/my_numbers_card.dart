import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/monitor/monitor_env.dart';
import 'package:letter_signing/monitor/monitor_screen.dart';
import 'package:letter_signing/monitor/report_ui.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';

/// "My numbers" (`GET /monitor/me`): open / overdue / done tasks, letters waiting, meetings
/// today, unread chat. Blocks of switched-off modules are simply missing and not shown.
class MyNumbersCard extends StatelessWidget {
  const MyNumbersCard({super.key, required this.env});
  final MonitorEnv env;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ReportView(
      load: env.api.me,
      builder: (context, d) {
        final tasks = asMap(d['tasks']);
        final letters = asMap(d['letters']);
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.monMyNumbers,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              StatWrap([
                if (d['tasks'] != null) ...[
                  StatTile(l.monOpenTasks, tasks['open']),
                  StatTile(l.monOverdue, tasks['overdue'], warn: true),
                  StatTile(l.monDone, tasks['done_in_period']),
                ],
                if (d['letters'] != null)
                  StatTile(l.monLettersWaiting, letters['waiting']),
                if (d['meetings_today'] != null)
                  StatTile(l.monMeetingsToday, d['meetings_today']),
                if (d['unread_chat'] != null)
                  StatTile(l.monUnreadChat, d['unread_chat']),
                if (intOf(d['reminders_today']) > 0)
                  StatTile(l.monRemindersToday, d['reminders_today']),
              ]),
            ],
          ),
        );
      },
    );
  }
}

/// Home page: the numbers card, plus the Monitoring entry for `monitor.view` holders.
class MyNumbersScreen extends StatelessWidget {
  const MyNumbersScreen({super.key, required this.env});
  final MonitorEnv env;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.monMyNumbers)),
      body: SizedBox.expand(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            SizedBox(height: 180, child: MyNumbersCard(env: env)),
            if (env.canMonitor)
              ListTile(
                key: const ValueKey('open-monitor'),
                leading: const Icon(Icons.monitor_heart_outlined),
                title: Text(l.monTitle),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MonitorScreen(env: env),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
