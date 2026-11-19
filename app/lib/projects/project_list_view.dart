import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/projects/project_views_controller.dart';
import 'package:letter_signing/tasks/models.dart';
import 'package:letter_signing/tasks/task_labels.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/widgets/progress_ring.dart';

/// Flat, table-like list of every task of the project with a search box and status filter.
class ProjectListView extends StatefulWidget {
  const ProjectListView({
    super.key,
    required this.controller,
    required this.onOpenTask,
  });

  final ProjectListController controller;
  final ValueChanged<String> onOpenTask;

  @override
  State<ProjectListView> createState() => _ProjectListViewState();
}

class _ProjectListViewState extends State<ProjectListView> {
  final _search = TextEditingController();

  ProjectListController get _c => widget.controller;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _c,
    builder: (context, _) => ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Tokens.gap,
        8,
        Tokens.gap,
        24,
      ),
      children: [
        _filters(context),
        const SizedBox(height: 8),
        ..._rows(context),
      ],
    ),
  );

  Widget _filters(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('list-search'),
          controller: _search,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: l.tasksSearchHint,
          ),
          onSubmitted: (v) => unawaited(_c.setQuery(v)),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final s in ['', ...TaskStatus.all])
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(
                      s.isEmpty ? l.tasksFilterAll : statusLabel(l, s),
                    ),
                    selected: _c.status == s,
                    onSelected: (_) => unawaited(_c.setStatus(s)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _rows(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_c.loading && _c.tasks.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_c.error != null && _c.tasks.isEmpty) {
      return [
        EmptyState(
          icon: Icons.cloud_off_outlined,
          title: l.tasksLoadFailed,
          action: OutlinedButton.icon(
            onPressed: () => unawaited(_c.load()),
            icon: const Icon(Icons.refresh),
            label: Text(l.commonRetry),
          ),
        ),
      ];
    }
    if (_c.tasks.isEmpty) {
      return [EmptyState(icon: Icons.checklist_rtl, title: l.projectListEmpty)];
    }
    return [
      for (final t in _c.tasks)
        _Row(
          key: ValueKey('row-${t.id}'),
          task: t,
          onTap: () => widget.onOpenTask(t.id),
        ),
    ];
  }
}

class _Row extends StatelessWidget {
  const _Row({super.key, required this.task, required this.onTap});

  final TaskBrief task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final due = task.dueAt;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusPill(
                          statusLabel(l, task.status),
                          tone: statusTone(task.status),
                        ),
                        if (task.priority != TaskPriority.normal)
                          StatusPill(
                            priorityLabel(l, task.priority),
                            tone: priorityTone(task.priority),
                          ),
                        if (due != null)
                          Text(
                            formatDue(due, allDay: task.allDay),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: task.isOverdue()
                                  ? Tokens.error
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ProgressRing(value: task.progress, size: 36),
            ],
          ),
        ),
      ),
    );
  }
}
