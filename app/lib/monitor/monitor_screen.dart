import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/monitor/customers_tab.dart';
import 'package:letter_signing/monitor/meetings_tab.dart';
import 'package:letter_signing/monitor/members_tab.dart';
import 'package:letter_signing/monitor/money_tabs.dart';
import 'package:letter_signing/monitor/monitor_api.dart';
import 'package:letter_signing/monitor/monitor_env.dart';
import 'package:letter_signing/monitor/overview_tab.dart';
import 'package:letter_signing/monitor/period_bar.dart';
import 'package:letter_signing/monitor/projects_tab.dart';
import 'package:letter_signing/monitor/tasks_tab.dart';

/// The Monitoring area (users with `monitor.view`). Tabs of switched-off modules are hidden;
/// Finance and Sales appear only when the server lets the caller read them.
class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key, required this.env, this.embedded = false});
  final MonitorEnv env;
  final bool embedded;

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  MonitorPeriod _period = const MonitorPeriod();
  bool _finance = false;
  bool _sales = false;
  bool _probed = false;

  MonitorEnv get _env => widget.env;

  @override
  void initState() {
    super.initState();
    unawaited(_probe());
  }

  Future<void> _probe() async {
    final fin = _env.isEnabled('finance')
        ? await _env.api.available('finance')
        : false;
    final sal = _env.isEnabled('sales')
        ? await _env.api.available('sales')
        : false;
    if (!mounted) return;
    setState(() {
      _finance = fin;
      _sales = sal;
      _probed = true;
    });
  }

  List<(String, Widget)> _tabs(AppLocalizations l) => [
    (l.monTabOverview, OverviewTab(env: _env, period: _period)),
    if (_env.isEnabled('projects') && _env.isEnabled('tasks'))
      (l.monTabProjects, ProjectsTab(env: _env)),
    if (_env.isEnabled('tasks')) (l.monTabTasks, TasksTab(env: _env)),
    if (_env.isEnabled('meetings'))
      (l.monTabMeetings, MeetingsTab(env: _env, period: _period)),
    (l.monTabMembers, MembersTab(env: _env, period: _period)),
    (l.monTabOnline, OnlineTab(env: _env)),
    if (_env.isEnabled('crm'))
      (l.monTabCustomers, CustomersTab(env: _env, period: _period)),
    if (_finance)
      (l.monTabFinance, FinanceMonitorTab(env: _env, period: _period)),
    if (_sales) (l.monTabSales, SalesMonitorTab(env: _env)),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (!_probed) return const Center(child: CircularProgressIndicator());
    final tabs = _tabs(l);
    return DefaultTabController(
      key: ValueKey(tabs.length),
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.embedded,
          title: Text(l.monTitle),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final t in tabs) Tab(text: t.$1)],
          ),
        ),
        body: Column(
          children: [
            PeriodBar(
              period: _period,
              onChanged: (p) => setState(() => _period = p),
            ),
            Expanded(
              child: TabBarView(
                // Horizontal swipes would fight bar charts and lists.
                physics: const NeverScrollableScrollPhysics(),
                children: [for (final t in tabs) t.$2],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
