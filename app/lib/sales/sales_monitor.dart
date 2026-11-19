import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/sales/leads_view.dart';
import 'package:letter_signing/sales/models.dart';
import 'package:letter_signing/sales/sales_env.dart';
import 'package:letter_signing/sales/sales_ui.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/money.dart';
import 'package:letter_signing/workspace/widgets/bar_chart.dart';

/// Sales monitoring: won against probable (weighted) and open value as stat cards and a chart,
/// open leads per probability bucket (tap one for its leads) and won value per Jalali month.
class SalesMonitorTab extends StatefulWidget {
  const SalesMonitorTab({super.key, required this.env});
  final SalesEnv env;

  @override
  State<SalesMonitorTab> createState() => _SalesMonitorTabState();
}

class _SalesMonitorTabState extends State<SalesMonitorTab> {
  SalesSummary? _summary;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final s = await widget.env.api.summary();
      if (mounted) setState(() => _summary = s);
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Widget _stat(String label, SalesTotal t, int amount, Color color) => Expanded(
    child: AppCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          AmountText(
            amount,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: color),
          ),
          Text(
            AppLocalizations.of(context)
                .salesCountValue(toPersianDigits(t.count)),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    ),
  );

  Widget _compare(AppLocalizations l, SalesSummary s) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _stat(l.salesMonitorWon, s.won, s.won.value, Tokens.ok),
            _stat(
              l.salesMonitorProbable,
              s.open,
              s.open.weighted,
              scheme.primary,
            ),
            _stat(
              l.salesMonitorOpen,
              s.open,
              s.open.value,
              scheme.onSurfaceVariant,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          l.salesMonitorChart,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        BarChart(
          labels: [
            l.salesMonitorWon,
            l.salesMonitorProbable,
            l.salesMonitorOpen,
          ],
          semanticsLabel: l.moneyChartLabel,
          series: [
            ChartSeries(
              l.salesMonitorChart,
              scheme.primary,
              [s.won.value, s.open.weighted, s.open.value],
              valueColors: [Tokens.ok, scheme.primary, scheme.outline],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buckets(AppLocalizations l, SalesSummary s) {
    final byName = {for (final b in s.byProbability) b.bucket: b};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.salesByBucket, style: Theme.of(context).textTheme.labelLarge),
        for (final name in leadBuckets)
          Builder(
            builder: (context) {
              final b = byName[name];
              return ListTile(
                key: ValueKey('bucket-$name'),
                contentPadding: EdgeInsets.zero,
                title: Text(bucketLabel(name)),
                subtitle: Text(
                  l.salesCountValue(toPersianDigits(b?.count ?? 0)),
                ),
                trailing: AmountText(b?.weighted ?? 0, withUnit: true),
                onTap: () => unawaited(
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) =>
                          LeadsBucketScreen(env: widget.env, bucket: name),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _months(AppLocalizations l, SalesSummary s) {
    if (s.wonByMonth.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.salesWonByMonth, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        BarChart(
          labels: [
            for (final m in s.wonByMonth)
              toPersianDigits(
                '${m.year}/${m.month.toString().padLeft(2, '0')}',
              ),
          ],
          semanticsLabel: l.moneyChartLabel,
          series: [
            ChartSeries(l.salesMonitorWon, Tokens.ok, [
              for (final m in s.wonByMonth) m.value,
            ]),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = _summary;
    if (_error != null && s == null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: l.salesLoadFailed,
        message: '$_error',
        action: OutlinedButton.icon(
          onPressed: () => unawaited(_load()),
          icon: const Icon(Icons.refresh),
          label: Text(l.commonRetry),
        ),
      );
    }
    if (s == null) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          _compare(l, s),
          const SizedBox(height: 16),
          _buckets(l, s),
          const SizedBox(height: 16),
          _months(l, s),
        ],
      ),
    );
  }
}
