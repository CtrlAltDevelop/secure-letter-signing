import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/monitor/monitor_env.dart';
import 'package:letter_signing/monitor/report_ui.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';

/// A colleague's active tasks (`GET /tasks/of/{user_id}`, `monitor.view` holders only).
class ColleagueTasksScreen extends StatelessWidget {
  const ColleagueTasksScreen({
    super.key,
    required this.env,
    required this.userId,
    required this.name,
  });
  final MonitorEnv env;
  final int userId;
  final String name;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('${l.monTheirTasks}: $name')),
      body: ReportView(
        load: () async => {'rows': await env.api.tasksOf(userId)},
        builder: (context, data) {
          final rows = asMapList(data['rows']);
          if (rows.isEmpty)
            return EmptyState(icon: Icons.task_alt, title: l.monEmpty);
          return ReportPage(
            children: [
              for (final t in rows)
                ListTile(
                  dense: true,
                  title: Text(asString(t['title'])),
                  subtitle: Text(dateOf(t['due_at'])),
                ),
            ],
          );
        },
      ),
    );
  }
}
