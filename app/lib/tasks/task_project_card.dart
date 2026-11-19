import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/projects/models.dart';
import 'package:letter_signing/projects/project_target_picker.dart';
import 'package:letter_signing/projects/projects_api.dart';
import 'package:letter_signing/tasks/models.dart';
import 'package:letter_signing/theme/widgets.dart';

/// Where a task lives: its project and column (when it is in a project) and the move and copy
/// actions.
class TaskProjectCard extends StatefulWidget {
  const TaskProjectCard({
    super.key,
    required this.task,
    required this.api,
    required this.onMove,
    required this.onCopy,
  });

  final TaskOut task;
  final ProjectsApi api;
  final void Function(String? projectId, int? columnId) onMove;
  final void Function(String? projectId) onCopy;

  @override
  State<TaskProjectCard> createState() => _TaskProjectCardState();
}

class _TaskProjectCardState extends State<TaskProjectCard> {
  ProjectOut? _project;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(TaskProjectCard old) {
    super.didUpdateWidget(old);
    if (old.task.projectId != widget.task.projectId) unawaited(_load());
  }

  Future<void> _load() async {
    final id = widget.task.projectId;
    if (id == null) {
      setState(() => _project = null);
      return;
    }
    try {
      final p = await widget.api.get(id);
      if (mounted) setState(() => _project = p);
    } on Object {
      // The name is decoration; the actions still work.
    }
  }

  String? get _columnTitle {
    final id = widget.task.columnId;
    return _project?.columns.where((c) => c.id == id).firstOrNull?.title;
  }

  Future<void> _pick({required bool copy}) async {
    final l = AppLocalizations.of(context);
    final target = await showDialog<({String? projectId, int? columnId})>(
      context: context,
      builder: (_) => _TargetDialog(
        api: widget.api,
        title: copy ? l.taskCopy : l.taskMove,
        withColumn: !copy,
        exclude: copy ? null : widget.task.projectId,
      ),
    );
    if (target == null) return;
    if (copy) {
      widget.onCopy(target.projectId);
    } else {
      widget.onMove(target.projectId, target.columnId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final task = widget.task;
    final project = _project;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (task.projectId != null)
            Text(
              [
                '${l.fieldProject}: ${project?.name ?? '…'}',
                if (_columnTitle != null) '${l.fieldColumn}: $_columnTitle',
              ].join(' · '),
              key: const ValueKey('task-project'),
            )
          else
            Text(l.taskNoProject),
          Wrap(
            spacing: 8,
            children: [
              if (task.canMove)
                TextButton.icon(
                  key: const ValueKey('task-move'),
                  onPressed: () => unawaited(_pick(copy: false)),
                  icon: const Icon(Icons.drive_file_move_outlined, size: 18),
                  label: Text(l.taskMove),
                ),
              TextButton.icon(
                key: const ValueKey('task-copy'),
                onPressed: () => unawaited(_pick(copy: true)),
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: Text(l.taskCopy),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TargetDialog extends StatefulWidget {
  const _TargetDialog({
    required this.api,
    required this.title,
    required this.withColumn,
    this.exclude,
  });

  final ProjectsApi api;
  final String title;
  final bool withColumn;
  final String? exclude;

  @override
  State<_TargetDialog> createState() => _TargetDialogState();
}

class _TargetDialogState extends State<_TargetDialog> {
  ProjectOut? _project;
  int? _column;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: ProjectTargetPicker(
          api: widget.api,
          excludeProjectId: widget.exclude,
          onChanged: (p, c) => setState(() {
            _project = p;
            _column = c;
          }),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('target-confirm'),
          onPressed: () => Navigator.pop(context, (
            projectId: _project?.id,
            columnId: widget.withColumn ? _column : null,
          )),
          child: Text(l.commonConfirm),
        ),
      ],
    );
  }
}
