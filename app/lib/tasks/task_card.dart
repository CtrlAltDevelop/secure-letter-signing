import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/tasks/models.dart';
import 'package:letter_signing/tasks/task_labels.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/widgets/progress_ring.dart';

/// One row of a task list: title, status/priority, due date (red when overdue), checklist
/// count, an unseen dot and the progress ring.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
    this.labels = const [],
    this.now,
  });

  final TaskBrief task;
  final VoidCallback onTap;
  final List<LabelInfo> labels;

  /// Clock for the overdue check (tests).
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _titleRow(context),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: _meta(context, l),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ProgressRing(value: task.progress),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _titleRow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (task.unseen)
          Container(
            key: const ValueKey('unseen-dot'),
            width: 8,
            height: 8,
            margin: const EdgeInsetsDirectional.only(end: 8),
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        Expanded(
          child: Text(
            task.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: task.unseen ? FontWeight.w700 : null,
              decoration: task.status == TaskStatus.cancelled
                  ? TextDecoration.lineThrough
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _meta(BuildContext context, AppLocalizations l) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5);
    final due = task.dueAt;
    final overdue = task.isOverdue(now);
    return [
      if (task.status != TaskStatus.open)
        StatusPill(statusLabel(l, task.status), tone: statusTone(task.status)),
      if (task.priority != TaskPriority.normal)
        StatusPill(
          priorityLabel(l, task.priority),
          tone: priorityTone(task.priority),
        ),
      if (due != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_outlined,
              size: 15,
              color: overdue ? Tokens.error : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              formatDue(due, allDay: task.allDay),
              key: const ValueKey('due-text'),
              style: overdue
                  ? muted.copyWith(
                      color: Tokens.error,
                      fontWeight: FontWeight.w700,
                    )
                  : muted,
            ),
          ],
        ),
      if (task.checklist.total > 0)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.checklist, size: 15, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              l.taskChecklistCount(
                toPersianDigits(task.checklist.done),
                toPersianDigits(task.checklist.total),
              ),
              style: muted,
            ),
          ],
        ),
      for (final lab in labels)
        if (task.labelIds.contains(lab.id)) Text('#${lab.name}', style: muted),
    ];
  }
}
