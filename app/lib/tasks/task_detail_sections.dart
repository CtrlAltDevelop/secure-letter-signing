import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/tasks/models.dart';
import 'package:letter_signing/tasks/task_labels.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/widgets/label_chips.dart';
import 'package:letter_signing/workspace/widgets/progress_ring.dart';

/// Title, status/priority pills, dates, labels and the creator.
class TaskHeaderCard extends StatelessWidget {
  const TaskHeaderCard({super.key, required this.task, required this.labels});
  final TaskOut task;
  final List<LabelInfo> labels;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 13);
    final due = task.dueAt;
    final overdue = task.isOverdue();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              StatusPill(
                statusLabel(l, task.status),
                tone: statusTone(task.status),
              ),
              StatusPill(
                priorityLabel(l, task.priority),
                tone: priorityTone(task.priority),
              ),
            ],
          ),
          if (task.startAt != null) ...[
            const SizedBox(height: 8),
            Text(
              '${l.fieldStart}: ${formatDue(task.startAt!, allDay: task.allDay)}',
              style: muted,
            ),
          ],
          if (due != null) ...[
            const SizedBox(height: 4),
            Text(
              '${l.fieldDue}: ${formatDue(due, allDay: task.allDay)}',
              key: const ValueKey('detail-due'),
              style: overdue
                  ? muted.copyWith(
                      color: Tokens.error,
                      fontWeight: FontWeight.w700,
                    )
                  : muted,
            ),
          ],
          if (task.creator != null) ...[
            const SizedBox(height: 4),
            Text(l.taskCreatedBy(task.creator!.displayName), style: muted),
          ],
          if (task.labelIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            LabelChips(labels: labels, selected: task.labelIds.toSet()),
          ],
        ],
      ),
    );
  }
}

/// Description text card.
class TaskDescriptionCard extends StatelessWidget {
  const TaskDescriptionCard({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.fieldDescription,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          SelectableText(text),
        ],
      ),
    );
  }
}

/// Progress ring and, for owners of a manual-mode task, a slider that saves on release.
class TaskProgressCard extends StatefulWidget {
  const TaskProgressCard({
    super.key,
    required this.task,
    required this.onChanged,
  });

  final TaskOut task;
  final ValueChanged<int> onChanged;

  @override
  State<TaskProgressCard> createState() => _TaskProgressCardState();
}

class _TaskProgressCardState extends State<TaskProgressCard> {
  late double _value = widget.task.progress.toDouble();

  @override
  void didUpdateWidget(TaskProgressCard old) {
    super.didUpdateWidget(old);
    if (old.task.progress != widget.task.progress) {
      _value = widget.task.progress.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final task = widget.task;
    final editable = task.progressEditable;
    return AppCard(
      child: Row(
        children: [
          ProgressRing(value: _value.round(), size: 56, strokeWidth: 5),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.fieldProgress,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (editable)
                  Slider(
                    key: const ValueKey('progress-slider'),
                    value: _value,
                    max: 100,
                    divisions: 20,
                    label: toPersianDigits(_value.round()),
                    onChanged: (v) => setState(() => _value = v),
                    onChangeEnd: (v) => widget.onChanged(v.round()),
                  )
                else if (task.progressMode == ProgressMode.checklist)
                  Text(l.taskProgressFromChecklist),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Owners, the approval chain with decisions, and followers.
class TaskPeopleCard extends StatelessWidget {
  const TaskPeopleCard({super.key, required this.task});
  final TaskOut task;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.titleSmall;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.fieldOwners, style: style),
          const SizedBox(height: 6),
          _chips(task.owners),
          if (task.approvers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(l.fieldApprovers, style: style),
            const SizedBox(height: 6),
            for (final a in task.approvers)
              _ApproverRow(
                approver: a,
                current: task.currentApprover?.user.id == a.user.id,
              ),
          ],
          if (task.followers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(l.fieldFollowers, style: style),
            const SizedBox(height: 6),
            _chips(task.followers),
          ],
        ],
      ),
    );
  }

  Widget _chips(List<UserRef> users) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final u in users)
        Chip(label: Text(u.displayName), visualDensity: VisualDensity.compact),
    ],
  );
}

class _ApproverRow extends StatelessWidget {
  const _ApproverRow({required this.approver, required this.current});
  final ApproverInfo approver;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (icon, color, text) = approver.approved
        ? (Icons.check_circle, Tokens.ok, l.approverApproved)
        : approver.rejected
        ? (Icons.cancel, Tokens.error, l.approverRejected)
        : (
            Icons.hourglass_empty,
            Theme.of(context).colorScheme.onSurfaceVariant,
            current ? l.approverTurn : l.approverPending,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              approver.user.displayName,
              style: TextStyle(
                fontWeight: current ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          Text(text, style: TextStyle(color: color, fontSize: 12.5)),
        ],
      ),
    );
  }
}

/// The checklist: tick, add, remove and drag to reorder, as far as the user may.
class TaskChecklistCard extends StatefulWidget {
  const TaskChecklistCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onAdd,
    required this.onRemove,
    required this.onMove,
  });

  final TaskOut task;
  final void Function(ChecklistItem item, {required bool done}) onToggle;
  final ValueChanged<String> onAdd;
  final ValueChanged<ChecklistItem> onRemove;
  final void Function(int oldIndex, int newIndex) onMove;

  @override
  State<TaskChecklistCard> createState() => _TaskChecklistCardState();
}

class _TaskChecklistCardState extends State<TaskChecklistCard> {
  final _add = TextEditingController();

  @override
  void dispose() {
    _add.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _add.text.trim();
    if (text.isEmpty) return;
    widget.onAdd(text);
    _add.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final task = widget.task;
    final items = task.checklistItems;
    final done = items.where((i) => i.done).length;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l.fieldChecklist} (${l.taskChecklistCount(toPersianDigits(done), toPersianDigits(items.length))})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: widget.onMove,
            children: [
              for (final (i, item) in items.indexed) _itemTile(l, i, item),
            ],
          ),
          if (task.canEditChecklist) _addRow(l),
        ],
      ),
    );
  }

  Widget _itemTile(AppLocalizations l, int index, ChecklistItem item) {
    final task = widget.task;
    return ListTile(
      key: ValueKey('item-${item.id}'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        value: item.done,
        onChanged: task.canTickChecklist
            ? (v) => widget.onToggle(item, done: v ?? false)
            : null,
      ),
      title: Text(
        item.text,
        style: item.done
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      trailing: task.canEditChecklist
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: l.checklistRemove,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => widget.onRemove(item),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle),
                ),
              ],
            )
          : null,
    );
  }

  Widget _addRow(AppLocalizations l) => Row(
    children: [
      Expanded(
        child: TextField(
          key: const ValueKey('checklist-add'),
          controller: _add,
          decoration: InputDecoration(hintText: l.checklistAddHint),
          onSubmitted: (_) => _submit(),
        ),
      ),
      IconButton(
        tooltip: l.checklistAdd,
        icon: const Icon(Icons.add),
        onPressed: _submit,
      ),
    ],
  );
}

/// Complete / approve / reject / reopen / cancel, as far as `can` and the status allow.
class TaskActionBar extends StatelessWidget {
  const TaskActionBar({
    super.key,
    required this.task,
    required this.busy,
    required this.onComplete,
    required this.onApprove,
    required this.onReject,
    required this.onReopen,
    required this.onCancel,
  });

  final TaskOut task;
  final bool busy;
  final VoidCallback onComplete;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onReopen;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    VoidCallback? guard(VoidCallback f) => busy ? null : f;
    final buttons = <Widget>[
      if (task.showComplete)
        FilledButton.icon(
          onPressed: guard(onComplete),
          icon: const Icon(Icons.check),
          label: Text(l.taskComplete),
        ),
      if (task.showDecision) ...[
        FilledButton.icon(
          onPressed: guard(onApprove),
          icon: const Icon(Icons.thumb_up_outlined),
          label: Text(l.taskApprove),
        ),
        OutlinedButton.icon(
          onPressed: guard(onReject),
          style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
          icon: const Icon(Icons.thumb_down_outlined),
          label: Text(l.taskReject),
        ),
      ],
      if (task.showReopen)
        OutlinedButton.icon(
          onPressed: guard(onReopen),
          icon: const Icon(Icons.replay),
          label: Text(l.taskReopen),
        ),
      if (task.showCancel)
        TextButton.icon(
          onPressed: guard(onCancel),
          style: TextButton.styleFrom(foregroundColor: scheme.error),
          icon: const Icon(Icons.block),
          label: Text(l.taskCancel),
        ),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }
}

/// Which lower section of the detail page is shown.
enum DetailTab { comments, files, history }

/// The chip row that switches between comments, files and history.
class DetailTabChips extends StatelessWidget {
  const DetailTabChips({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.commentCount,
    required this.fileCount,
  });

  final DetailTab selected;
  final ValueChanged<DetailTab> onSelected;
  final int commentCount;
  final int fileCount;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final labels = {
      DetailTab.comments: '${l.tabComments} (${toPersianDigits(commentCount)})',
      DetailTab.files: '${l.tabFiles} (${toPersianDigits(fileCount)})',
      DetailTab.history: l.tabHistory,
    };
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final e in labels.entries)
          ChoiceChip(
            label: Text(e.value),
            selected: selected == e.key,
            onSelected: (_) => onSelected(e.key),
          ),
      ],
    );
  }
}
