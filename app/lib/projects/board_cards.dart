import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/tasks/models.dart';
import 'package:letter_signing/tasks/task_card.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';

/// A task on the board: the full [TaskCard], or a one-line [compact] version.
class BoardCard extends StatelessWidget {
  const BoardCard({
    super.key,
    required this.task,
    required this.onTap,
    this.compact = false,
    this.labels = const [],
  });

  final TaskBrief task;
  final VoidCallback onTap;
  final bool compact;
  final List<LabelInfo> labels;

  @override
  Widget build(BuildContext context) {
    if (!compact) {
      return TaskCard(task: task, labels: labels, onTap: onTap);
    }
    final scheme = Theme.of(context).colorScheme;
    final due = task.dueAt;
    final overdue = task.isOverdue();
    final l = AppLocalizations.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                decoration: task.status == TaskStatus.cancelled
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
          ),
          if (due != null) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.event_outlined,
              size: 14,
              color: overdue ? Tokens.error : scheme.onSurfaceVariant,
            ),
          ],
          const SizedBox(width: 8),
          Text(
            l.percentValue(toPersianDigits(task.progress)),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Column title, task count and the percentage of finished tasks as a thin bar.
class ColumnHeaderInfo extends StatelessWidget {
  const ColumnHeaderInfo({
    super.key,
    required this.title,
    required this.count,
    required this.percent,
    this.trailing = const [],
  });

  final String title;
  final int count;
  final int percent;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            StatusPill(toPersianDigits(count)),
            ...trailing,
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  key: const ValueKey('column-progress'),
                  value: percent / 100,
                  minHeight: 6,
                  backgroundColor: scheme.onSurface.withValues(alpha: 0.10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l.percentValue(toPersianDigits(percent)),
              key: const ValueKey('column-percent'),
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}
