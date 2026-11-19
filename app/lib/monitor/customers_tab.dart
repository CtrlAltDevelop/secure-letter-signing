import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/monitor/monitor_api.dart';
import 'package:letter_signing/monitor/monitor_env.dart';
import 'package:letter_signing/monitor/report_ui.dart';
import 'package:letter_signing/workspace/models.dart';

/// Customer files: status counts and the quietest files first.
class CustomersTab extends StatelessWidget {
  const CustomersTab({super.key, required this.env, required this.period});
  final MonitorEnv env;
  final MonitorPeriod period;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ReportView(
      key: ValueKey('customers-${period.query()}'),
      load: () => env.api.customers(period),
      builder: (context, data) => ReportPage(
        children: [
          StatWrap([
            StatTile(l.monCustomerTotal, data['total']),
            StatTile(l.monCreatedInPeriod, data['created_in_period']),
            StatTile(l.monQuiet, data['quiet'], warn: true),
            for (final e in asMap(data['by_status']).entries)
              StatTile(e.key, e.value),
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              l.monQuietHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          for (final c in asMapList(data['customers']))
            ListTile(
              dense: true,
              title: Text(asString(c['name'])),
              subtitle: Text(
                '${l.monLastEvent}: ${dateOf(c['last_event_at'], l.monNever)}',
              ),
              trailing: LtrText(
                '${fmtNum(c['open_tasks'])} / ${fmtNum(c['overdue_tasks'])}',
              ),
            ),
        ],
      ),
    );
  }
}
