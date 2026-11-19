import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/finance/finance_docs_view.dart';
import 'package:letter_signing/finance/finance_env.dart';
import 'package:letter_signing/finance/finance_form_screen.dart';
import 'package:letter_signing/finance/finance_monitor.dart';
import 'package:letter_signing/finance/finance_report.dart';
import 'package:letter_signing/finance/models.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/theme/widgets.dart';

/// The Finance module: documents, performance report and income monitoring.
class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key, required this.env});
  final FinanceEnv env;

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  // Bumped after a document was created so the tabs reload.
  int _generation = 0;

  Future<void> _new() async {
    final doc = await Navigator.of(context).push<FinanceDoc>(
      MaterialPageRoute(builder: (_) => FinanceFormScreen(env: widget.env)),
    );
    if (doc != null && mounted) setState(() => _generation++);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => unawaited(_new()),
          tooltip: l.financeNew,
          icon: const Icon(Icons.add),
          label: Text(l.financeNew),
        ),
        body: Column(
          children: [
            TabBar(
              tabs: [
                Tab(text: l.financeTabDocs),
                Tab(text: l.financeTabReport),
                Tab(text: l.financeTabMonitor),
              ],
            ),
            Expanded(
              child: PageBody(
                child: TabBarView(
                  children: [
                    FinanceDocsView(
                      key: ValueKey('docs-$_generation'),
                      env: widget.env,
                      showFilters: true,
                    ),
                    FinanceReportTab(
                      key: ValueKey('report-$_generation'),
                      env: widget.env,
                    ),
                    FinanceMonitorTab(
                      key: ValueKey('mon-$_generation'),
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
