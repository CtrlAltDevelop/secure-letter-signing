import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:material_ui/material_ui.dart' show MaterialPageRoute, Navigator;

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/bookmarks/bookmarks_api.dart';
import 'package:letter_signing/calendar/calendar_api.dart';
import 'package:letter_signing/calendar/calendar_env.dart';
import 'package:letter_signing/chat/chat_api.dart';
import 'package:letter_signing/chat/chat_env.dart';
import 'package:letter_signing/chat/chat_opener.dart';
import 'package:letter_signing/chat/chat_panel.dart';
import 'package:letter_signing/crm/crm_api.dart';
import 'package:letter_signing/crm/crm_env.dart';
import 'package:letter_signing/crm/crm_opener.dart';
import 'package:letter_signing/finance/finance_api.dart';
import 'package:letter_signing/finance/finance_env.dart';
import 'package:letter_signing/gantt/gantt_api.dart';
import 'package:letter_signing/gantt/gantt_env.dart';
import 'package:letter_signing/gantt/gantt_screen.dart';
import 'package:letter_signing/tasks/task_detail_screen.dart';
import 'package:letter_signing/letters/letters_api.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/meetings/meetings_api.dart';
import 'package:letter_signing/meetings/meetings_env.dart';
import 'package:letter_signing/monitor/monitor_api.dart';
import 'package:letter_signing/monitor/monitor_env.dart';
import 'package:letter_signing/notes/notes_api.dart';
import 'package:letter_signing/notes/notes_env.dart';
import 'package:letter_signing/polls/polls_api.dart';
import 'package:letter_signing/polls/polls_env.dart';
import 'package:letter_signing/prefs/prefs_api.dart';
import 'package:letter_signing/prefs/prefs_controller.dart';
import 'package:letter_signing/projects/projects_env.dart';
import 'package:letter_signing/sales/sales_api.dart';
import 'package:letter_signing/finance/customer_finance_panel.dart';
import 'package:letter_signing/sales/customer_leads_panel.dart';
import 'package:letter_signing/sales/sales_env.dart';
import 'package:letter_signing/search/search_api.dart';
import 'package:letter_signing/tasks/tasks_api.dart';
import 'package:letter_signing/tasks/tasks_env.dart';
import 'package:letter_signing/workspace/open_router.dart';
import 'package:letter_signing/workspace/open_target.dart';

/// Codes of every module this app build knows how to show.
const knownModuleCodes = [
  'tasks',
  'projects',
  'letters',
  'meetings',
  'chat',
  'finance',
  'sales',
  'gantt',
  'crm',
];

/// Modules a guest may use; the server's `/me/modules` is the authority, this is only the
/// default until it answers.
const guestModuleCodes = ['tasks', 'projects', 'chat'];

/// What every module needs after login: the API client, the one live stream, the user and
/// which modules the company plan enables. Built once by the home screen.
class WorkspaceEnv extends ChangeNotifier {
  WorkspaceEnv({
    required this.api,
    required this.live,
    required this.user,
    required this.letters,
  }) {
    letters.tasksResolver ??= () => tasks;
    openers['chat'] = (context, target) => chatOpener(chat)(context, target);
    openers['crm'] = (context, target) => crmOpener(crm)(context, target);
  }

  /// Wires the shared [LiveService] into the letters env for a signed-in user.
  factory WorkspaceEnv.forAuth(
    AuthController auth, {
    required String deviceName,
    LiveService? live,
  }) {
    final user = auth.user!;
    final shared =
        live ?? LiveService(api: auth.api, cursor: SecureCursorStore(user.id));
    return WorkspaceEnv(
      api: auth.api,
      live: shared,
      user: user,
      letters: LettersEnv(
        api: LettersApi(auth.api),
        live: shared,
        userId: user.id,
        biometrics: auth.biometrics,
        enrollBiometric: auth.enrollBiometric,
        canCreate: user.permissions.contains('letter.create'),
        isManager: user.isManager,
        canSecretariat: user.permissions.contains('letter.secretariat'),
        deviceName: deviceName,
        sessionId: () => auth.sessionId,
      ),
    );
  }

  final ApiClient api;
  final LiveService live;
  final UserInfo user;
  final LettersEnv letters;

  /// Tasks module dependencies, built on first use from the shared client and live stream.
  late final TasksEnv tasks = TasksEnv(
    api: TasksApi(api),
    live: live,
    userId: user.id,
    userName: user.fullName,
    canCreate: user.permissions.contains('task.create'),
  );

  /// Projects module dependencies, built on first use.
  late final ProjectsEnv projects = ProjectsEnv(
    chatTab: (projectId) => isEnabled('chat')
        ? ProjectChatTab(env: chat, projectId: projectId)
        : null,
    ganttTab: (projectId) =>
        isEnabled('gantt') ? GanttTab(env: gantt, projectId: projectId) : null,
    api: tasks.projects,
    tasks: tasks,
    live: live,
    userId: user.id,
    canCreate: user.permissions.contains('project.create'),
    isManager: user.isManager,
  );

  /// Gantt dependencies (the project tab, shown only while module `gantt` is enabled).
  late final GanttEnv gantt = GanttEnv(
    api: GanttApi(tasks.api.workspace),
    openTask: (context, taskId) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskDetailScreen(env: tasks, taskId: taskId),
      ),
    ),
  );

  /// Meetings module dependencies, built on first use.
  late final MeetingsEnv meetings = MeetingsEnv(
    api: MeetingsApi(tasks.api.workspace),
    live: live,
    userId: user.id,
    tasks: tasks,
    userName: user.fullName,
    isManager: user.isManager,
    biometrics: letters.biometrics,
  );

  /// Chat dependencies, built on first use (CRM screens embed `CustomerChatTab(env: chat, ...)`).
  late final ChatEnv chat = ChatEnv(
    api: ChatApi(tasks.api.workspace),
    live: live,
    userId: user.id,
    tasks: tasks,
    userName: user.fullName,
    canCreateGroup: user.permissions.contains('chat.create_group'),
  );

  /// Notes dependencies, built on first use (opened from search and bookmarks).
  late final NotesEnv notes = NotesEnv(
    api: NotesApi(tasks.api.workspace),
    live: live,
    userId: user.id,
  );

  /// Polls dependencies, built on first use (chat, projects and customer files embed `PollsSection`).
  late final PollsEnv polls = PollsEnv(
    api: PollsApi(tasks.api.workspace),
    live: live,
    userId: user.id,
  );

  /// Openers other modules (chat, CRM ...) register for their own targets; they win over the
  /// built-in screens of [openTarget].
  final Map<String, TargetOpener> openers = {};

  /// Opens a calendar item, search hit, bookmark, pin or mention.
  Future<void> open(BuildContext context, OpenTarget target) =>
      openTarget(context, this, target);

  /// Calendar dependencies; `monitor.view` enables the team calendar.
  late final CalendarEnv calendar = CalendarEnv(
    api: CalendarApi(tasks.api.workspace),
    tasks: tasks,
    projects: tasks.projects,
    open: open,
    canMonitor: user.permissions.contains('monitor.view'),
    userId: user.id,
  );

  /// Monitoring dependencies; `monitor.view` unlocks the Monitoring area, "My numbers" is for all.
  late final MonitorEnv monitor = MonitorEnv(
    api: MonitorApi(tasks.api.workspace),
    canMonitor: user.permissions.contains('monitor.view'),
    isEnabled: isEnabled,
    directory: tasks.directory,
  );

  late final SearchApi searchApi = SearchApi(tasks.api.workspace);
  late final BookmarksApi bookmarks = BookmarksApi(tasks.api.workspace);
  late final PrefsController prefs = PrefsController(
    PrefsApi(tasks.api.workspace),
  );

  /// Finance module dependencies (permission `finance.manage`), built on first use.
  late final FinanceEnv finance = FinanceEnv(
    api: FinanceApi(tasks.api.workspace),
    live: live,
    userId: user.id,
  );

  /// Sales module dependencies (permission `sales.manage`), built on first use.
  late final SalesEnv sales = SalesEnv(
    api: SalesApi(tasks.api.workspace),
    live: live,
    userId: user.id,
  );

  /// CRM (customer files) dependencies, built on first use. Finance, leads and chat panels
  /// show only when that module is enabled and (finance, sales) the user holds its permission.
  late final CrmEnv crm = CrmEnv(
    api: CrmApi(tasks.api.workspace),
    live: live,
    userId: user.id,
    tasks: tasks,
    meetings: meetings,
    letters: letters,
    canCreate: user.permissions.contains('customer.create'),
    canImport: user.permissions.contains('customer.import'),
    financePanel: (id) =>
        isEnabled('finance') && user.permissions.contains('finance.manage')
        ? CustomerFinancePanel(env: finance, customerId: id)
        : null,
    leadsPanel: (id) =>
        isEnabled('sales') && user.permissions.contains('sales.manage')
        ? CustomerLeadsPanel(env: sales, customerId: id)
        : null,
    chatTab: (id) =>
        isEnabled('chat') ? CustomerChatTab(env: chat, customerId: id) : null,
  );

  late Set<String> _enabled = user.isGuest
      ? {...guestModuleCodes}
      : {...knownModuleCodes};
  String _plan = '';

  /// Codes of the modules shown to this user.
  Set<String> get enabledModules => Set.unmodifiable(_enabled);
  String get plan => _plan;
  bool isEnabled(String code) => _enabled.contains(code);

  /// Reads `GET /me/modules` (`{"plan", "modules": [{"code", "enabled"}]}`). An older server
  /// (404) or a network failure leaves every known module enabled.
  Future<void> loadModules() async {
    try {
      final data = await api.call('GET', '/me/modules');
      final parsed = _parse(data);
      if (parsed == null) return;
      _enabled = parsed.enabled;
      _plan = parsed.plan;
      notifyListeners();
    } on Object {
      // Keep the all-enabled default.
    }
  }

  static ({Set<String> enabled, String plan})? _parse(Object? data) {
    if (data is! Map || data['modules'] is! List) return null;
    final enabled = <String>{};
    for (final m in data['modules'] as List) {
      if (m is Map && m['enabled'] == true && m['code'] is String) {
        enabled.add(m['code'] as String);
      }
    }
    return (enabled: enabled, plan: (data['plan'] as String?) ?? '');
  }

  /// Stops the controllers and the shared live stream.
  Future<void> disposeAll() async {
    prefs.dispose();
    await letters.dispose();
    await live.dispose();
    dispose();
  }
}
