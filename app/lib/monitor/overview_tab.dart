import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/monitor/charts.dart';
import 'package:letter_signing/monitor/monitor_env.dart';
import 'package:letter_signing/monitor/monitor_api.dart';
import 'package:letter_signing/monitor/report_ui.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';

/// Desk charts per period: chat messages, letters, tasks, customers (blocks of disabled
/// modules are absent from the server answer).
class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key, required this.env, required this.period});
  final MonitorEnv env;
  final MonitorPeriod period;

  @override
  Widget build(BuildContext context) => ReportView(
    key: ValueKey('overview-${period.query()}'),
    load: () => env.api.overview(period),
    builder: (context, data) {
      final l = AppLocalizations.of(context);
      final mods = asMap(data['modules']);
      final blocks = <(String, String, String)>[
        ('chat', l.monChat, 'messages'),
        ('letters', l.monLetters, 'created'),
        ('letters', l.monLetters, 'signed'),
        ('tasks', l.monTasks, 'created'),
        ('tasks', l.monTasks, 'completed'),
        ('tasks', l.monTasks, 'overdue'),
        ('crm', l.monCustomers, 'created'),
        ('crm', l.monCustomers, 'activity'),
      ];
      String seriesName(String key) => switch (key) {
        'messages' => l.monMessages,
        'created' => l.monCreated,
        'completed' => l.monCompleted,
        'signed' => l.monSigned,
        'overdue' => l.monOverdue,
        'activity' => l.monEvents,
        _ => key,
      };
      final cards = [
        for (final (code, title, key) in blocks)
          if (asMap(asMap(asMap(mods[code])['series']))[key] is List)
            _chartCard(
              context,
              '$title: ${seriesName(key)}',
              pointsOf(asMap(asMap(mods[code])['series'])[key]),
            ),
      ];
      if (cards.isEmpty)
        return EmptyState(icon: Icons.insights, title: l.monEmpty);
      return ReportPage(children: cards);
    },
  );

  Widget _chartCard(BuildContext context, String title, List<ChartPoint> pts) {
    final total = pts.fold<num>(0, (s, p) => s + p.value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                LtrText(fmtNum(total)),
              ],
            ),
            const SizedBox(height: 8),
            BarChart(points: pts),
          ],
        ),
      ),
    );
  }
}
