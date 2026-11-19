import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/monitor/charts.dart';
import 'package:letter_signing/monitor/monitor_api.dart';
import 'package:letter_signing/monitor/monitor_env.dart';
import 'package:letter_signing/monitor/report_ui.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';

/// Finance monitoring: net per bucket as a bar chart plus the period totals.
class FinanceMonitorTab extends StatelessWidget {
  const FinanceMonitorTab({super.key, required this.env, required this.period});
  final MonitorEnv env;
  final MonitorPeriod period;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final names = {
      'confirmed_receipts': l.monReceipts,
      'confirmed_payments': l.monPayments,
      'net': l.monNet,
      'probable_receipts': l.monProbableReceipts,
      'probable_payments': l.monProbablePayments,
      'overdue_receipts': l.monOverdueReceipts,
      'overdue_payments': l.monOverduePayments,
    };
    return ReportView(
      key: ValueKey('finance-${period.query()}'),
      load: () => env.api.finance(period),
      builder: (context, data) {
        final totals = asMap(data['totals']);
        final buckets = asMapList(data['buckets']);
        return ReportPage(
          children: [
            StatWrap([
              for (final e in names.entries) StatTile(e.value, totals[e.key]),
            ]),
            if (buckets.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: AppCard(
                  child: BarChart(
                    points: [
                      for (final b in buckets)
                        ChartPoint(asString(b['period']), intOf(b['net'])),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Sales monitoring: lead counts by status and the open / won / lost summaries.
class SalesMonitorTab extends StatelessWidget {
  const SalesMonitorTab({super.key, required this.env});
  final MonitorEnv env;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ReportView(
      load: env.api.sales,
      builder: (context, data) {
        final by = asMap(data['by_status']);
        return ReportPage(
          children: [
            StatWrap([
              StatTile(l.monSalesOpen, by['open']),
              StatTile(l.monSalesWon, by['won']),
              StatTile(l.monSalesLost, by['lost']),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AppCard(
                child: BarChart(
                  points: [
                    for (final m in asMapList(data['won_by_month']))
                      ChartPoint(
                        asString(m['label'], asString(m['period'])),
                        intOf(m['value'] ?? m['total'] ?? m['count']),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
