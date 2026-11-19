import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/projects/models.dart';
import 'package:letter_signing/projects/projects_api.dart';

/// Project and column dropdowns. Lists the active projects the user can put tasks into; when
/// the list cannot be loaded or is empty nothing is shown. [onChanged] reports the chosen
/// project (loaded in full, so callers know its members) and column.
class ProjectTargetPicker extends StatefulWidget {
  const ProjectTargetPicker({
    super.key,
    required this.api,
    required this.onChanged,
    this.projectId,
    this.columnId,
    this.allowNone = true,
    this.excludeProjectId,
  });

  final ProjectsApi api;
  final String? projectId;
  final int? columnId;

  /// Offers "no project" (a personal task).
  final bool allowNone;

  /// A project to leave out (the one a task is already in).
  final String? excludeProjectId;
  final void Function(ProjectOut? project, int? columnId) onChanged;

  @override
  State<ProjectTargetPicker> createState() => _ProjectTargetPickerState();
}

class _ProjectTargetPickerState extends State<ProjectTargetPicker> {
  List<ProjectBrief> _projects = const [];
  ProjectOut? _project;
  int? _columnId;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _columnId = widget.columnId;
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final all = await widget.api.list(status: ProjectStatus.active);
      final usable = [
        for (final p in all)
          if (p.myRole != ProjectRole.viewer && p.id != widget.excludeProjectId)
            p,
      ];
      final id = widget.projectId;
      final project = id == null ? null : await widget.api.get(id);
      if (!mounted) return;
      setState(() {
        _projects = usable;
        _project = project;
        _loaded = true;
      });
      if (project != null) {
        widget.onChanged(project, _columnId ?? _defaultColumn(project));
      }
    } on Object {
      // No projects module or no access: the picker stays hidden.
    }
  }

  int? _defaultColumn(ProjectOut p) {
    final todo = p.columns.where((c) => c.kind == ColumnKind.todo).firstOrNull;
    return (todo ?? p.columns.firstOrNull)?.id;
  }

  Future<void> _pickProject(String? id) async {
    if (id == null) {
      setState(() {
        _project = null;
        _columnId = null;
      });
      widget.onChanged(null, null);
      return;
    }
    try {
      final project = await widget.api.get(id);
      if (!mounted) return;
      final column = _defaultColumn(project);
      setState(() {
        _project = project;
        _columnId = column;
      });
      widget.onChanged(project, column);
    } on Object {
      // Keep the previous choice when the project cannot be read.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || (_projects.isEmpty && _project == null)) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    final known = {for (final p in _projects) p.id};
    final current = _project;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String?>(
          key: const ValueKey('target-project'),
          isExpanded: true,
          initialValue: current?.id,
          decoration: InputDecoration(labelText: l.fieldProject),
          items: [
            if (widget.allowNone)
              DropdownMenuItem<String?>(
                value: null,
                child: Text(l.projectNone),
              ),
            if (current != null && !known.contains(current.id))
              DropdownMenuItem<String?>(
                value: current.id,
                child: Text(current.name, overflow: TextOverflow.ellipsis),
              ),
            for (final p in _projects)
              DropdownMenuItem<String?>(
                value: p.id,
                child: Text(p.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (id) => unawaited(_pickProject(id)),
        ),
        if (current != null && current.columns.isNotEmpty) ...[
          const SizedBox(height: 12),
          KeyedSubtree(
            key: ValueKey('column-of-${current.id}'),
            child: DropdownButtonFormField<int>(
              key: const ValueKey('target-column'),
              isExpanded: true,
              initialValue: _columnId,
              decoration: InputDecoration(labelText: l.fieldColumn),
              items: [
                for (final c in current.columns)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(c.title, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (id) {
                setState(() => _columnId = id);
                widget.onChanged(current, id);
              },
            ),
          ),
        ],
      ],
    );
  }
}
