import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/finance/finance_docs_view.dart';
import 'package:letter_signing/finance/finance_env.dart';
import 'package:letter_signing/finance/models.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/money.dart';

/// Monitoring of income still to come: totals of probable and overdue receipts, then every
/// pending receipt, overdue ones first (oldest due date first).
class FinanceMonitorTab extends StatefulWidget {
  const FinanceMonitorTab({super.key, required this.env});
  final FinanceEnv env;

  @override
  State<FinanceMonitorTab> createState() => _FinanceMonitorTabState();
}

class _FinanceMonitorTabState extends State<FinanceMonitorTab> {
  FinanceStats? _totals;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final s = await widget.env.api.summary(groupBy: 'year');
      if (mounted) setState(() => _totals = s.totals);
    } on Object {
      // The list below still works; the totals are an extra.
    }
  }

  static int _byDue(FinanceDoc a, FinanceDoc b) {
    if (a.overdue != b.overdue) return a.overdue ? -1 : 1;
    return a.reportDate.compareTo(b.reportDate);
  }

  Widget _header(AppLocalizations l) {
    final t = _totals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.financeMonitorTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (t != null)
          Row(
            key: const ValueKey('monitor-totals'),
            children: [
              _card(l.financeMonitorOverdue, t.overdueReceipts, Tokens.error),
              _card(
                l.financeMonitorUpcoming,
                t.probableReceipts - t.overdueReceipts,
                Tokens.ok,
              ),
            ],
          ),
      ],
    );
  }

  Widget _card(String label, int value, Color color) => Expanded(
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          AmountText(
            value,
            withUnit: true,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: color),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FinanceDocsView(
      env: widget.env,
      initialFilter: const FinanceFilter(
        direction: FinanceDirection.receipt,
        statuses: [FinanceStatus.pending],
      ),
      sort: _byDue,
      header: _header(l),
      emptyTitle: l.financeMonitorEmpty,
      emptyMessage: '',
    );
  }
}
