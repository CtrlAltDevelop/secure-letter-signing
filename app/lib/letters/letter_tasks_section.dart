import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/tasks/models.dart';
import 'package:letter_signing/tasks/task_detail_screen.dart';
import 'package:letter_signing/tasks/task_form_screen.dart';
import 'package:letter_signing/tasks/task_labels.dart';
import 'package:letter_signing/theme/widgets.dart';

/// The tasks linked to a letter: open one, link an existing task (picker), unlink, or create a
/// new task from the letter. [onChanged] asks the screen to reload the letter.
class LetterTasksSection extends StatelessWidget {
  const LetterTasksSection({
    super.key,
    required this.env,
    required this.letter,
    required this.onChanged,
  });
  final LettersEnv env;
  final LetterDetail letter;
  final VoidCallback onChanged;

  Future<void> _run(BuildContext context, Future<Object?> Function() f) async {
    try {
      await f();
      onChanged();
    } on Object catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _link(BuildContext context) async {
    final picked = await showModalBottomSheet<TaskBrief>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _TaskPicker(env: env, exclude: {for (final t in letter.tasks) t.id}),
    );
    if (picked == null || !context.mounted) return;
    await _run(context, () => env.v2.linkTask(letter.id, picked.id));
  }

  Future<void> _create(BuildContext context) async {
    final resolver = env.tasksResolver;
    if (resolver == null) return;
    final l = AppLocalizations.of(context);
    final number = letter.brief.numberLabel.isEmpty
        ? '#${toPersianDigits(letter.brief.no)}'
        : toPersianDigits(letter.brief.numberLabel);
    final created = await Navigator.of(context).push<TaskOut>(
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(
          env: resolver(),
          initialDraft: TaskDraft(
            title: l.letterTaskTitle(letter.title),
            description: l.letterTaskDescription(number, letter.title),
          ),
        ),
      ),
    );
    if (created == null || !context.mounted) return;
    await _run(context, () => env.v2.linkTask(letter.id, created.id));
  }

  void _open(BuildContext context, TaskBrief t) {
    final resolver = env.tasksResolver;
    if (resolver == null) return;
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => TaskDetailScreen(env: resolver(), taskId: t.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final canTasks = env.tasksResolver != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(l.letterTasksTitle),
        if (canTasks)
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: () => unawaited(_link(context)),
                icon: const Icon(Icons.link, size: 18),
                label: Text(l.letterTaskLink),
              ),
              TextButton.icon(
                onPressed: () => unawaited(_create(context)),
                icon: const Icon(Icons.add_task, size: 18),
                label: Text(l.letterTaskCreate),
              ),
            ],
          ),
        if (letter.tasks.isEmpty)
          AppCard(child: Text(l.letterTasksEmpty))
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final t in letter.tasks)
                  ListTile(
                    dense: true,
                    title: Text(
                      t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(statusLabel(l, t.status)),
                    onTap: canTasks ? () => _open(context, t) : null,
                    trailing: IconButton(
                      tooltip: l.letterTaskUnlink,
                      icon: const Icon(Icons.link_off),
                      onPressed: () => unawaited(
                        _run(context, () => env.v2.unlinkTask(letter.id, t.id)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TaskPicker extends StatefulWidget {
  const _TaskPicker({required this.env, required this.exclude});
  final LettersEnv env;
  final Set<String> exclude;

  @override
  State<_TaskPicker> createState() => _TaskPickerState();
}

class _TaskPickerState extends State<_TaskPicker> {
  List<TaskBrief>? _rows;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_search(''));
  }

  Future<void> _search(String q) async {
    try {
      final rows = await widget.env.v2.searchTasks(q);
      if (!mounted) return;
      setState(() {
        _rows = [
          for (final t in rows)
            if (!widget.exclude.contains(t.id)) t,
        ];
        _error = null;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Widget _list(AppLocalizations l) {
    final rows = _rows;
    if (_error != null) {
      return Padding(padding: const EdgeInsets.all(24), child: Text('$_error'));
    }
    if (rows == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l.letterTaskPickerEmpty),
      );
    }
    return ListView(
      shrinkWrap: true,
      children: [
        for (final t in rows)
          ListTile(
            dense: true,
            title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(statusLabel(l, t.status)),
            onTap: () => Navigator.of(context).pop(t),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l.tasksSearchHint,
                  ),
                  onChanged: (v) => unawaited(_search(v.trim())),
                ),
              ),
              Flexible(child: _list(l)),
            ],
          ),
        ),
      ),
    );
  }
}
