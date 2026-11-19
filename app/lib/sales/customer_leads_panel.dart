import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/sales/lead_form_screen.dart';
import 'package:letter_signing/sales/models.dart';
import 'package:letter_signing/sales/sales_env.dart';
import 'package:letter_signing/sales/sales_ui.dart';
import 'package:letter_signing/theme/widgets.dart';

/// The leads of one customer file, with a button to add a lead for this customer. Meant to
/// sit inside the customer file screen; show it only when the user holds `sales.manage` and
/// the module is enabled.
class CustomerLeadsPanel extends StatefulWidget {
  const CustomerLeadsPanel({
    super.key,
    required this.env,
    required this.customerId,
  });
  final SalesEnv env;
  final String customerId;

  @override
  State<CustomerLeadsPanel> createState() => _CustomerLeadsPanelState();
}

class _CustomerLeadsPanelState extends State<CustomerLeadsPanel> {
  List<Lead>? _leads;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final v = await widget.env.api.forCustomer(widget.customerId);
      if (mounted) setState(() => _leads = v);
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _open({Lead? lead}) async {
    await Navigator.of(context).push<Lead>(
      MaterialPageRoute(
        builder: (_) => LeadFormScreen(
          env: widget.env,
          lead: lead,
          customerId: widget.customerId,
        ),
      ),
    );
    if (mounted) unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final leads = _leads;
    return Column(
      key: const ValueKey('customer-leads'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          l.salesCustomerTitle,
          trailing: IconButton(
            tooltip: l.salesNew,
            icon: const Icon(Icons.add),
            onPressed: () => unawaited(_open()),
          ),
        ),
        if (_error != null && leads == null)
          Text('$_error')
        else if (leads == null)
          const Center(child: CircularProgressIndicator())
        else ...[
          if (leads.isEmpty) Text(l.salesCustomerEmpty),
          for (final lead in leads)
            LeadTile(
              lead: lead,
              onTap: () => unawaited(_open(lead: lead)),
            ),
        ],
      ],
    );
  }
}
