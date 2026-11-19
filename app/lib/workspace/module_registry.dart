import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/chat/chat_screen.dart';
import 'package:letter_signing/crm/customers_screen.dart';
import 'package:letter_signing/finance/finance_screen.dart';
import 'package:letter_signing/letters/letters_list_screen.dart';
import 'package:letter_signing/meetings/meetings_screen.dart';
import 'package:letter_signing/sales/sales_screen.dart';
import 'package:letter_signing/tasks/tasks_screen.dart';
import 'package:letter_signing/projects/projects_screen.dart';
import 'package:letter_signing/workspace/workspace_env.dart';

/// One product area shown in the home shell (Tasks, Projects, Letters, ...).
@immutable
class AppModule {
  const AppModule({
    required this.code,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.build,
    this.permission,
  });

  /// Server-side module code, as in `GET /me/modules`.
  final String code;
  final String Function(AppLocalizations l) label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function(WorkspaceEnv env) build;

  /// Permission the user must hold besides the module being enabled (null: none).
  final String? permission;
}

/// Every module this build knows, in bottom-bar order.
final List<AppModule> appModules = [
  AppModule(
    code: 'tasks',
    label: (l) => l.moduleTasks,
    icon: Icons.task_alt_outlined,
    selectedIcon: Icons.task_alt,
    build: (env) => TasksScreen(env: env.tasks),
  ),
  AppModule(
    code: 'projects',
    label: (l) => l.moduleProjects,
    icon: Icons.folder_outlined,
    selectedIcon: Icons.folder,
    build: (env) => ProjectsScreen(env: env.projects),
  ),
  AppModule(
    code: 'letters',
    label: (l) => l.moduleLetters,
    icon: Icons.mail_outline,
    selectedIcon: Icons.mail,
    build: (env) => LettersListScreen(env: env.letters, embedded: true),
  ),
  AppModule(
    code: 'meetings',
    label: (l) => l.moduleMeetings,
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups,
    build: (env) => MeetingsScreen(env: env.meetings),
  ),
  AppModule(
    code: 'chat',
    label: (l) => l.moduleChat,
    icon: Icons.chat_bubble_outline,
    selectedIcon: Icons.chat_bubble,
    build: (env) => ChatScreen(env: env.chat),
  ),
  AppModule(
    code: 'finance',
    label: (l) => l.moduleFinance,
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
    build: (env) => FinanceScreen(env: env.finance),
    permission: 'finance.manage',
  ),
  AppModule(
    code: 'sales',
    label: (l) => l.moduleSales,
    icon: Icons.trending_up,
    selectedIcon: Icons.trending_up,
    build: (env) => SalesScreen(env: env.sales),
    permission: 'sales.manage',
  ),
  AppModule(
    code: 'crm',
    label: (l) => l.moduleCrm,
    icon: Icons.contacts_outlined,
    selectedIcon: Icons.contacts,
    build: (env) => CustomersScreen(env: env.crm),
  ),
];

/// The modules [env] enables, in registry order.
List<AppModule> enabledModules(WorkspaceEnv env) => [
  for (final m in appModules)
    if (env.isEnabled(m.code) &&
        (m.permission == null || env.user.permissions.contains(m.permission)))
      m,
];
