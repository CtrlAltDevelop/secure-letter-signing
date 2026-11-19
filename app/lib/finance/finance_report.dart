import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/finance/finance_docs_view.dart';
import 'package:letter_signing/finance/finance_env.dart';
import 'package:letter_signing/finance/models.dart';
import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/widgets/choice_row.dart';
import 'package:letter_signing/workspace/money.dart';
import 'package:letter_signing/workspace/widgets/bar_chart.dart';
import 'package:letter_signing/workspace/widgets/label_chips.dart';

/// Jalali period title: `اردیبهشت ۱۴۰۵` for a month, `۱۴۰۵` for a year.
String bucketTitle(FinanceBucket b) {
  final y = b.jalaliYear;
  final m = b.jalaliMonth;
  if (y == null) return b.period;
  if (m == null || m < 1 || m > 12) return toPersianDigits(y);
  return '${jalaliMonthNames[m - 1]} ${toPersianDigits(y)}';
}

/// Short chart axis label: `۱۴۰۵/۰۲` or `۱۴۰۵`.
String bucketShort(FinanceBucket b) {
  final y = b.jalaliYear;
  final m = b.jalaliMonth;
  if (y == null) return b.period;
  return toPersianDigits(
    m == null ? '$y' : '$y/${m.toString().padLeft(2, '0')}',
  );
}

/// The performance report: monthly or yearly Jalali buckets as a chart and a table of
/// confirmed receipts, payments and net; a row opens that period's documents.
class FinanceReportTab extends StatefulWidget {
  const FinanceReportTab({super.key, required this.env});
  final FinanceEnv env;

  @override
  State<FinanceReportTab> createState() => _FinanceReportTabState();
}

class _FinanceReportTabState extends State<FinanceReportTab> {
  String _group = 'month';
  int? _labelId;
  FinanceSummary? _summary;
  Object? _error;
  List<LabelInfo> _labels = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(
      widget.env.labels().then((v) {
        if (mounted) setState(() => _labels = v);
      }),
    );
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final s = await widget.env.api.summary(
        groupBy: _group,
        labelId: _labelId,
      );
      if (mounted) setState(() => _summary = s);
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _drill(FinanceBucket b) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => FinanceDrillScreen(
            env: widget.env,
            title: AppLocalizations.of(context)
                .financeDrillTitle(bucketTitle(b)),
            filter: FinanceFilter(
              from: b.start,
              to: b.end,
              statuses: const [FinanceStatus.confirmed, FinanceStatus.pending],
              labelId: _labelId,
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, int value, {Color? color}) => Expanded(
    child: AppCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          AmountText(
            value,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: color),
          ),
        ],
      ),
    ),
  );

  Widget _stats(AppLocalizations l, FinanceStats t) => Column(
    children: [
      Row(
        children: [
          _stat(l.financeProbableReceipts, t.probableReceipts),
          _stat(l.financeProbablePayments, t.probablePayments),
        ],
      ),
      Row(
        children: [
          _stat(
            l.financeOverdueReceipts,
            t.overdueReceipts,
            color: Tokens.error,
          ),
          _stat(l.financeProjectedNet, t.projectedNet),
        ],
      ),
    ],
  );

  Widget _row(
    String a,
    Widget b,
    Widget c,
    Widget d, {
    VoidCallback? onTap,
    bool bold = false,
  }) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.w700) : null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: DefaultTextStyle.merge(
          style: style,
          child: Row(
            children: [
              Expanded(flex: 3, child: Text(a)),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: b,
                ),
              ),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: c,
                ),
              ),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: d,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _table(AppLocalizations l, FinanceSummary s) {
    final head = Theme.of(context).textTheme.labelMedium;
    Widget h(String t) => Text(t, style: head);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        key: const ValueKey('report-table'),
        children: [
          _row(
            l.financeColPeriod,
            h(l.financeColReceipts),
            h(l.financeColPayments),
            h(l.financeColNet),
          ),
          const Divider(height: 1),
          for (final b in s.buckets)
            _row(
              bucketTitle(b),
              AmountText(b.stats.confirmedReceipts),
              AmountText(b.stats.confirmedPayments),
              AmountText(b.stats.net),
              onTap: () => _drill(b),
            ),
          const Divider(height: 1),
          _row(
            l.financeTotals,
            AmountText(s.totals.confirmedReceipts),
            AmountText(s.totals.confirmedPayments),
            AmountText(s.totals.net),
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _chart(AppLocalizations l, FinanceSummary s) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(l.financeChartTitle, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      BarChart(
        labels: [for (final b in s.buckets) bucketShort(b)],
        semanticsLabel: l.moneyChartLabel,
        series: [
          ChartSeries(l.financeColReceipts, Tokens.ok, [
            for (final b in s.buckets) b.stats.confirmedReceipts,
          ]),
          ChartSeries(l.financeColPayments, Tokens.error, [
            for (final b in s.buckets) b.stats.confirmedPayments,
          ]),
        ],
      ),
      Wrap(
        spacing: 16,
        children: [
          _legend(Tokens.ok, l.financeColReceipts),
          _legend(Tokens.error, l.financeColPayments),
        ],
      ),
    ],
  );

  Widget _legend(Color c, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10, color: c),
      const SizedBox(width: 6),
      Text(t, style: Theme.of(context).textTheme.labelSmall),
    ],
  );

  Widget _content(AppLocalizations l) {
    final s = _summary;
    if (_error != null && s == null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: l.financeLoadFailed,
        message: '$_error',
        action: OutlinedButton.icon(
          onPressed: () => unawaited(_load()),
          icon: const Icon(Icons.refresh),
          label: Text(l.commonRetry),
        ),
      );
    }
    if (s == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (s.buckets.isEmpty) {
      return EmptyState(icon: Icons.bar_chart, title: l.financeReportEmpty);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stats(l, s.totals),
        const SizedBox(height: 12),
        _chart(l, s),
        const SizedBox(height: 12),
        _table(l, s),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          ChoiceRow(
            options: {
              'month': l.financeReportMonthly,
              'year': l.financeReportYearly,
            },
            value: _group,
            onChanged: (v) {
              if (v == _group) return;
              setState(() {
                _group = v;
                _summary = null;
              });
              unawaited(_load());
            },
          ),
          if (_labels.isNotEmpty)
            LabelChips(
              labels: _labels,
              selected: {?_labelId},
              single: true,
              onChanged: (s) {
                setState(() {
                  _labelId = s.isEmpty ? null : s.first;
                  _summary = null;
                });
                unawaited(_load());
              },
            ),
          const SizedBox(height: 12),
          _content(l),
        ],
      ),
    );
  }
}
