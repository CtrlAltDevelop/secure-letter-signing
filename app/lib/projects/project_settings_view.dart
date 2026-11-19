import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/projects/models.dart';
import 'package:letter_signing/projects/project_controller.dart';
import 'package:letter_signing/projects/project_ui.dart';
import 'package:letter_signing/tasks/task_dialogs.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/subject_controller.dart'
    show ActionOutcome;

/// Members with their roles, the project's dates and status, and for managers: edit, finish,
/// archive and copy-with-structure.
class ProjectSettingsView extends StatefulWidget {
  const ProjectSettingsView({
    super.key,
    required this.controller,
    required this.onEdit,
    required this.onCopied,
  });

  final ProjectController controller;
  final VoidCallback onEdit;
  final ValueChanged<ProjectOut> onCopied;

  @override
  State<ProjectSettingsView> createState() => _ProjectSettingsViewState();
}

class _ProjectSettingsViewState extends State<ProjectSettingsView> {
  bool _copyAvailable = true;

  ProjectController get _c => widget.controller;

  Future<void> _setStatus(String status) async {
    final outcome = await _c.setStatus(status);
    if (mounted) reportOutcome(context, outcome, _c.lastError);
  }

  Future<void> _archive() async {
    final l = AppLocalizations.of(context);
    final yes = await showConfirmDialog(
      context,
      title: l.projectArchive,
      message: l.projectArchiveConfirm,
      confirmLabel: l.projectArchive,
    );
    if (yes) await _setStatus(ProjectStatus.archived);
  }

  Future<void> _copy(ProjectOut project) async {
    final l = AppLocalizations.of(context);
    final name = await showTextPrompt(
      context,
      title: l.projectCopy,
      confirmLabel: l.projectCopy,
      initial: l.projectCopyName(project.name),
    );
    if (name == null || !mounted) return;
    final outcome = await _c.copyProject(name, copied: widget.onCopied);
    if (!mounted) return;
    if (outcome == ActionOutcome.notFound) {
      setState(() => _copyAvailable = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.projectCopyUnavailable)));
      return;
    }
    reportOutcome(context, outcome, _c.lastError);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _c,
    builder: (context, _) {
      final project = _c.project;
      if (project == null) return const SizedBox.shrink();
      return ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          Tokens.gap,
          8,
          Tokens.gap,
          32,
        ),
        children: [
          _info(context, project),
          const SizedBox(height: 12),
          _members(context, project),
          const SizedBox(height: 12),
          ..._actions(context, project),
        ],
      );
    },
  );

  Widget _info(BuildContext context, ProjectOut p) {
    final l = AppLocalizations.of(context);
    final muted = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 13,
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPill(
            projectStatusLabel(l, p.status),
            tone: projectStatusTone(p.status),
          ),
          if (p.description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(p.description),
          ],
          if (p.startDate != null)
            Text(
              '${l.fieldStart}: ${formatJalaliDate(p.startDate!)}',
              style: muted,
            ),
          if (p.endDate != null)
            Text(
              '${l.projectEnd}: ${formatJalaliDate(p.endDate!)}',
              style: muted,
            ),
        ],
      ),
    );
  }

  Widget _members(BuildContext context, ProjectOut p) {
    final l = AppLocalizations.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.projectMembers, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          for (final m in p.members)
            Padding(
              key: ValueKey('member-${m.user.id}'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      m.user.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusPill(
                    projectRoleLabel(l, m.role),
                    tone: m.role == ProjectRole.manager
                        ? Tone.info
                        : Tone.neutral,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context, ProjectOut p) {
    final l = AppLocalizations.of(context);
    if (!p.isManager && !p.can.edit) return const [];
    return [
      if (p.can.edit && !p.isArchived)
        OutlinedButton.icon(
          key: const ValueKey('project-edit'),
          onPressed: widget.onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: Text(l.projectEdit),
        ),
      if (p.isManager) ..._managerActions(context, p),
    ];
  }

  List<Widget> _managerActions(BuildContext context, ProjectOut p) {
    final l = AppLocalizations.of(context);
    Widget button(Key key, IconData icon, String label, VoidCallback onTap) =>
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: OutlinedButton.icon(
            key: key,
            onPressed: onTap,
            icon: Icon(icon),
            label: Text(label),
          ),
        );
    return [
      if (p.status == ProjectStatus.active)
        button(
          const ValueKey('project-done'),
          Icons.check_circle_outline,
          l.projectMarkDone,
          () => unawaited(_setStatus(ProjectStatus.done)),
        ),
      if (p.status != ProjectStatus.active)
        button(
          const ValueKey('project-reactivate'),
          Icons.replay,
          l.projectReactivate,
          () => unawaited(_setStatus(ProjectStatus.active)),
        ),
      if (!p.isArchived)
        button(
          const ValueKey('project-archive'),
          Icons.archive_outlined,
          l.projectArchive,
          () => unawaited(_archive()),
        ),
      if (_copyAvailable)
        button(
          const ValueKey('project-copy'),
          Icons.copy_all_outlined,
          l.projectCopy,
          () => unawaited(_copy(p)),
        ),
    ];
  }
}
