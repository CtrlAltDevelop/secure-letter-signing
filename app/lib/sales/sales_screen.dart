import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/sales/lead_form_screen.dart';
import 'package:letter_signing/sales/leads_view.dart';
import 'package:letter_signing/sales/models.dart';
import 'package:letter_signing/sales/sales_env.dart';
import 'package:letter_signing/sales/sales_monitor.dart';
import 'package:letter_signing/theme/widgets.dart';

/// The Sales module: leads and sales monitoring.
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key, required this.env});
  final SalesEnv env;

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  // Bumped after a lead was created so the tabs reload.
  int _generation = 0;

  Future<void> _new() async {
    final lead = await Navigator.of(context).push<Lead>(
      MaterialPageRoute(builder: (_) => LeadFormScreen(env: widget.env)),
    );
    if (lead != null && mounted) setState(() => _generation++);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => unawaited(_new()),
          tooltip: l.salesNew,
          icon: const Icon(Icons.add),
          label: Text(l.salesNew),
        ),
        body: Column(
          children: [
            TabBar(
              tabs: [
                Tab(text: l.salesTabLeads),
                Tab(text: l.salesTabMonitor),
              ],
            ),
            Expanded(
              child: PageBody(
                child: TabBarView(
                  children: [
                    LeadsView(
                      key: ValueKey('leads-$_generation'),
                      env: widget.env,
                      showFilters: true,
                    ),
                    SalesMonitorTab(
                      key: ValueKey('monitor-$_generation'),
                      env: widget.env,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
