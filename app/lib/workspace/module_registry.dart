import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letters_list_screen.dart';
import 'package:letter_signing/meetings/meetings_screen.dart';
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
  });

  /// Server-side module code, as in `GET /me/modules`.
  final String code;
  final String Function(AppLocalizations l) label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function(WorkspaceEnv env) build;
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
];

/// The modules [env] enables, in registry order.
List<AppModule> enabledModules(WorkspaceEnv env) => [
  for (final m in appModules)
    if (env.isEnabled(m.code)) m,
];
