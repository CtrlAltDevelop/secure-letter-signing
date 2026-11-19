import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/gantt/gantt_controller.dart';
import 'package:letter_signing/gantt/gantt_models.dart';
import 'package:letter_signing/gantt/gantt_plan.dart';
import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/jalali/jalali_picker.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/theme/app_theme.dart';

/// Result of [showDatesDialog]: the chosen days (either may be null = cleared).
typedef DayRange = ({DateTime? start, DateTime? end});

Future<DateTime?> _pick(BuildContext context, DateTime? initial) => showJalaliDatePicker(
  context,
  initialDate: initial == null ? null : DateTime(initial.year, initial.month, initial.day),
);

/// Start and end of a task or phase through two Jalali pickers. The end may not precede the start.
Future<DayRange?> showDatesDialog(
  BuildContext context, {
  required String title,
  DateTime? start,
  DateTime? end,
}) => showDialog<DayRange>(
  context: context,
  builder: (_) => _DatesDialog(title: title, start: start, end: end),
);

class _DatesDialog extends StatefulWidget {
  const _DatesDialog({required this.title, this.start, this.end});
  final String title;
  final DateTime? start;
  final DateTime? end;

  @override
  State<_DatesDialog> createState() => _DatesDialogState();
}

class _DatesDialogState extends State<_DatesDialog> {
  late DateTime? _start = widget.start;
  late DateTime? _end = widget.end;
  String? _error;

  Future<void> _choose({required bool start}) async {
    final d = await _pick(context, start ? _start : _end);
    if (d == null) return;
    setState(() {
      if (start) {
        _start = asDay(d);
      } else {
        _end = asDay(d);
      }
      _error = null;
    });
  }

  void _save() {
    final l = AppLocalizations.of(context);
    if (_start != null && _end != null && _end!.isBefore(_start!)) {
      setState(() => _error = l.gnDatesOrder);
      return;
    }
    Navigator.pop(context, (start: _start, end: _end));
  }

  Widget _button(String label, DateTime? value, String keyName, bool start) => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          key: ValueKey(keyName),
          icon: const Icon(Icons.event, size: 18),
          label: Text('$label: ${value == null ? '—' : formatJalaliDate(value)}'),
          onPressed: () => _choose(start: start),
        ),
      ),
      IconButton(
        tooltip: AppLocalizations.of(context).jalaliFieldClear,
        icon: const Icon(Icons.clear, size: 18),
        onPressed: value == null
            ? null
            : () => setState(() {
                if (start) {
                  _start = null;
                } else {
                  _end = null;
                }
              }),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _button(l.gnStart, _start, 'dates-start', true),
          const SizedBox(height: 8),
          _button(l.gnEnd, _end, 'dates-end', false),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Tokens.error)),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.commonCancel)),
        FilledButton(key: const ValueKey('dates-save'), onPressed: _save, child: Text(l.commonSave)),
      ],
    );
  }
}

/// One text field dialog (phase title); null when cancelled or empty.
Future<String?> showTitleDialog(BuildContext context, {required String title, String initial = ''}) =>
    showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController(text: initial);
        final l = AppLocalizations.of(ctx);
        void done() {
          final v = c.text.trim();
          Navigator.pop(ctx, v.isEmpty ? null : v);
        }

        return AlertDialog(
          title: Text(title),
          content: TextField(
            key: const ValueKey('title-field'),
            controller: c,
            autofocus: true,
            maxLength: 200,
            onSubmitted: (_) => done(),
            decoration: InputDecoration(labelText: l.gnPhaseTitle),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.commonCancel)),
            FilledButton(key: const ValueKey('title-save'), onPressed: done, child: Text(l.commonSave)),
          ],
        );
      },
    );

/// Phase picker: the chosen phase id, `-1` for "no phase" (top level), null when cancelled.
Future<int?> showPhasePicker(BuildContext context, GanttChart chart, {int? current}) =>
    showDialog<int>(
      context: context,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        return SimpleDialog(
          title: Text(l.gnMoveToPhase),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, -1),
              child: Text(l.gnNoPhase),
            ),
            for (final p in chart.phases)
              if (p.active)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, p.id),
                  child: Text('${p.wbs}  ${p.title}'),
                ),
          ],
        );
      },
    );

/// Predecessors of one task: list with remove, and a picker to add (finish-to-start).
Future<void> showDependenciesDialog(
  BuildContext context,
  GanttController controller,
  GanttItem item,
  void Function(String message) report,
) => showDialog<void>(
  context: context,
  builder: (ctx) => ListenableBuilder(
    listenable: controller,
    builder: (ctx, _) {
      final l = AppLocalizations.of(ctx);
      final chart = controller.chart!;
      final preds = [for (final k in chart.links) if (k.successorId == item.taskId) k];
      final candidates = predecessorCandidates(chart, item.taskId);
      return AlertDialog(
        title: Text(l.gnDependencies),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.gnDependenciesHelp(item.title)),
              const SizedBox(height: 8),
              if (preds.isEmpty) Text(l.gnNoDependencies),
              for (final k in preds)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    chart.item(k.predecessorId)?.title ?? k.predecessorId,
                    style: k.conflict ? const TextStyle(color: Tokens.error) : null,
                  ),
                  subtitle: k.conflict ? Text(l.gnConflict) : null,
                  trailing: IconButton(
                    key: ValueKey('dep-remove-${k.id}'),
                    tooltip: l.gnRemoveDependency,
                    icon: const Icon(Icons.link_off),
                    onPressed: controller.busy
                        ? null
                        : () async {
                            final err = await controller.removeLink(k.id);
                            if (err != null) report(err);
                          },
                  ),
                ),
              const Divider(),
              if (candidates.isNotEmpty)
                DropdownButton<String>(
                  key: const ValueKey('dep-add'),
                  isExpanded: true,
                  hint: Text(l.gnAddDependency),
                  items: [
                    for (final c in candidates)
                      DropdownMenuItem(
                        value: c.taskId,
                        child: Text('${c.wbs}  ${c.title}', overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: controller.busy
                      ? null
                      : (id) async {
                          if (id == null) return;
                          final err = await controller.addLink(id, item.taskId);
                          if (err != null) report(err);
                        },
                ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.commonConfirm))],
      );
    },
  ),
);

/// Dialog for adding an unplanned task to the plan: phase and dates.
typedef AddToPlan = ({int? phaseId, DateTime? start, DateTime? end});

Future<AddToPlan?> showAddToPlanDialog(
  BuildContext context,
  GanttChart chart,
  GanttUnplanned task,
) => showDialog<AddToPlan>(
  context: context,
  builder: (_) => _AddToPlanDialog(chart: chart, task: task),
);

class _AddToPlanDialog extends StatefulWidget {
  const _AddToPlanDialog({required this.chart, required this.task});
  final GanttChart chart;
  final GanttUnplanned task;

  @override
  State<_AddToPlanDialog> createState() => _AddToPlanDialogState();
}

class _AddToPlanDialogState extends State<_AddToPlanDialog> {
  int? _phase;
  late DateTime? _start = widget.task.start;
  late DateTime? _end = widget.task.end;

  Future<void> _dates() async {
    final l = AppLocalizations.of(context);
    final r = await showDatesDialog(context, title: l.gnSetDates, start: _start, end: _end);
    if (r == null) return;
    setState(() {
      _start = r.start;
      _end = r.end;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final phases = [for (final p in widget.chart.phases) if (p.active) p];
    return AlertDialog(
      title: Text(widget.task.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int?>(
            key: const ValueKey('plan-phase'),
            initialValue: _phase,
            decoration: InputDecoration(labelText: l.gnPhase),
            items: [
              DropdownMenuItem<int?>(value: null, child: Text(l.gnNoPhase)),
              for (final p in phases) DropdownMenuItem<int?>(value: p.id, child: Text(p.title)),
            ],
            onChanged: (v) => setState(() => _phase = v),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('plan-dates'),
            icon: const Icon(Icons.event, size: 18),
            label: Text(
              _start == null && _end == null
                  ? l.gnSetDates
                  : '${_start == null ? '—' : formatJalaliDate(_start!)} → ${_end == null ? '—' : formatJalaliDate(_end!)}',
            ),
            onPressed: _dates,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.commonCancel)),
        FilledButton(
          key: const ValueKey('plan-add'),
          onPressed: () => Navigator.pop(context, (phaseId: _phase, start: _start, end: _end)),
          child: Text(l.gnAddToPlan),
        ),
      ],
    );
  }
}
