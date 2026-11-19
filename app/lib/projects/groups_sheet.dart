import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/projects/models.dart';
import 'package:letter_signing/projects/project_ui.dart';
import 'package:letter_signing/projects/projects_controller.dart';

/// Opens the project group management sheet.
Future<void> showGroupsSheet(
  BuildContext context,
  ProjectsController controller, {
  required bool isManager,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => GroupsSheet(controller: controller, isManager: isManager),
);

/// Create, rename and deactivate project groups. Organisation groups can be changed only by
/// the company manager; personal groups by their owner.
class GroupsSheet extends StatefulWidget {
  const GroupsSheet({
    super.key,
    required this.controller,
    required this.isManager,
  });

  final ProjectsController controller;
  final bool isManager;

  @override
  State<GroupsSheet> createState() => _GroupsSheetState();
}

class _GroupsSheetState extends State<GroupsSheet> {
  ProjectsController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    unawaited(_c.loadAllGroups());
  }

  bool _canEdit(ProjectGroup g) => !g.isOrg || widget.isManager;

  Future<void> _create() async {
    final l = AppLocalizations.of(context);
    final scope = await _askScope();
    if (scope == null || !mounted) return;
    final name = await showTextPrompt(
      context,
      title: l.groupNew,
      confirmLabel: l.commonSave,
      hint: l.groupNameHint,
    );
    if (name == null || !mounted) return;
    final outcome = await _c.createGroup(name, scope: scope);
    if (mounted) reportOutcome(context, outcome, _c.lastError);
  }

  /// Managers choose between an organisation and a personal group; everyone else gets personal.
  Future<String?> _askScope() async {
    if (!widget.isManager) return 'personal';
    final l = AppLocalizations.of(context);
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.groupScopeTitle),
        children: [
          SimpleDialogOption(
            key: const ValueKey('scope-org'),
            onPressed: () => Navigator.pop(ctx, 'org'),
            child: Text(l.groupScopeOrg),
          ),
          SimpleDialogOption(
            key: const ValueKey('scope-personal'),
            onPressed: () => Navigator.pop(ctx, 'personal'),
            child: Text(l.groupScopePersonal),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(ProjectGroup g) async {
    final l = AppLocalizations.of(context);
    final name = await showTextPrompt(
      context,
      title: l.groupRename,
      confirmLabel: l.commonSave,
      initial: g.name,
    );
    if (name == null || !mounted) return;
    final outcome = await _c.renameGroup(g.id, name);
    if (mounted) reportOutcome(context, outcome, _c.lastError);
  }

  Future<void> _toggle(ProjectGroup g) async {
    final outcome = await _c.setGroupActive(g.id, active: !g.active);
    if (mounted) reportOutcome(context, outcome, _c.lastError);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ListenableBuilder(
          listenable: _c,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.groupsTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      key: const ValueKey('group-new'),
                      onPressed: () => unawaited(_create()),
                      icon: const Icon(Icons.add),
                      label: Text(l.groupNew),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: _c.groups.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(l.groupsEmpty),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [for (final g in _c.groups) _tile(l, g)],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(AppLocalizations l, ProjectGroup g) {
    final editable = _canEdit(g);
    return ListTile(
      key: ValueKey('group-${g.id}'),
      leading: Icon(g.isOrg ? Icons.apartment_outlined : Icons.person_outline),
      title: Text(
        g.name,
        style: g.active
            ? null
            : TextStyle(color: Theme.of(context).disabledColor),
      ),
      subtitle: Text(g.isOrg ? l.groupScopeOrg : l.groupScopePersonal),
      trailing: editable
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: ValueKey('group-rename-${g.id}'),
                  tooltip: l.groupRename,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => unawaited(_rename(g)),
                ),
                IconButton(
                  key: ValueKey('group-toggle-${g.id}'),
                  tooltip: g.active ? l.groupDeactivate : l.groupActivate,
                  icon: Icon(
                    g.active
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () => unawaited(_toggle(g)),
                ),
              ],
            )
          : null,
    );
  }
}
