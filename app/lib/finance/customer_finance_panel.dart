import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/finance/finance_env.dart';
import 'package:letter_signing/finance/finance_form_screen.dart';
import 'package:letter_signing/finance/finance_ui.dart';
import 'package:letter_signing/finance/models.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/money.dart';

/// The financial report of one customer file: totals and the linked documents, with a button
/// to add a document for this customer. Meant to sit inside the customer file screen; show it
/// only when the user holds `finance.manage` and the module is enabled.
class CustomerFinancePanel extends StatefulWidget {
  const CustomerFinancePanel({
    super.key,
    required this.env,
    required this.customerId,
  });
  final FinanceEnv env;
  final String customerId;

  @override
  State<CustomerFinancePanel> createState() => _CustomerFinancePanelState();
}

class _CustomerFinancePanelState extends State<CustomerFinancePanel> {
  CustomerFinance? _data;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final d = await widget.env.api.customer(widget.customerId);
      if (mounted) setState(() => _data = d);
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _open({FinanceDoc? doc}) async {
    await Navigator.of(context).push<FinanceDoc>(
      MaterialPageRoute(
        builder: (_) => FinanceFormScreen(
          env: widget.env,
          doc: doc,
          customerId: widget.customerId,
        ),
      ),
    );
    if (mounted) unawaited(_load());
  }

  Widget _totals(AppLocalizations l, FinanceStats t) => Wrap(
    spacing: 16,
    runSpacing: 4,
    children: [
      _fig(l.financeColReceipts, t.confirmedReceipts, Tokens.ok),
      _fig(l.financeColPayments, t.confirmedPayments, Tokens.error),
      _fig(l.financeColNet, t.net, null),
      _fig(l.financeProbableReceipts, t.probableReceipts, null),
    ],
  );

  Widget _fig(String label, int v, Color? color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      AmountText(v, withUnit: true, style: TextStyle(color: color)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final d = _data;
    return Column(
      key: const ValueKey('customer-finance'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          l.financeCustomerTitle,
          trailing: IconButton(
            tooltip: l.financeNew,
            icon: const Icon(Icons.add),
            onPressed: () => unawaited(_open()),
          ),
        ),
        if (_error != null && d == null)
          Text('$_error')
        else if (d == null)
          const Center(child: CircularProgressIndicator())
        else ...[
          _totals(l, d.totals),
          const SizedBox(height: 8),
          if (d.documents.isEmpty) Text(l.financeCustomerEmpty),
          for (final doc in d.documents)
            FinanceDocTile(
              doc: doc,
              onTap: () => unawaited(_open(doc: doc)),
            ),
        ],
      ],
    );
  }
}
