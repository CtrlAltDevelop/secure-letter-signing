import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/gantt/gantt_controller.dart';
import 'package:letter_signing/gantt/gantt_dialogs.dart';
import 'package:letter_signing/gantt/gantt_env.dart';
import 'package:letter_signing/gantt/gantt_models.dart';
import 'package:letter_signing/gantt/gantt_painter.dart';
import 'package:letter_signing/gantt/gantt_print_screen.dart';
import 'package:letter_signing/gantt/gantt_scale.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/theme/widgets.dart';

const double _treeWidth = 280;
const double _headerHeight = ganttHeaderRowHeight * 2;

/// The project's Gantt tab: WBS tree on one side, the timeline on the other, one vertical
/// scroll for both. Read-only unless the server says `can_edit`.
class GanttTab extends StatefulWidget {
  const GanttTab({
    super.key,
    required this.env,
    required this.projectId,
    this.controller,
  });
  final GanttEnv env;
  final String projectId;

  /// Replaces the default controller (tests).
  final GanttController? controller;

  @override
  State<GanttTab> createState() => _GanttTabState();
}

class _GanttTabState extends State<GanttTab> {
  late final GanttController _c =
      widget.controller ?? GanttController(widget.env.api, widget.projectId);
  final _body = ScrollController();
  final _header = ScrollController();
  final _drag = ValueNotifier<BarDrag?>(null);
  ({String taskId, DragMode mode})? _hit;
  double _dx = 0;
  bool _positioned = false;

  @override
  void initState() {
    super.initState();
    _body.addListener(() {
      if (_header.hasClients && _header.offset != _body.offset)
        _header.jumpTo(_body.offset);
    });
    unawaited(_c.load());
  }

  @override
  void dispose() {
    _body.dispose();
    _header.dispose();
    _drag.dispose();
    if (widget.controller == null) _c.dispose();
    super.dispose();
  }

  void _report(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _do(Future<String?> edit) async {
    final failure = await edit;
    if (failure != null) _report(failure);
  }

  /// First time the chart shows: bring today (or the start) into view.
  void _scrollToToday() {
    if (_positioned || !_body.hasClients) return;
    _positioned = true;
    final scale = _c.scale;
    final target = scale.x(DateTime.now()) - 120;
    final max = _body.position.maxScrollExtent;
    _body.jumpTo(target.clamp(0.0, max));
  }

  // ---- drag ----

  bool _probe(Offset at) {
    _hit = _c.canEdit ? hitBar(_c.scale, _c.rows, at) : null;
    _dx = 0;
    return _hit != null;
  }

  void _dragUpdate(DragUpdateDetails d) {
    final hit = _hit;
    if (hit == null) return;
    _dx += d.delta.dx;
    _drag.value = BarDrag(
      hit.taskId,
      hit.mode,
      (_dx / _c.scale.dayWidth).round(),
    );
  }

  void _dragCancel() {
    _hit = null;
    _drag.value = null;
  }

  void _dragEnd() {
    final hit = _hit;
    final days = _drag.value?.days ?? 0;
    _hit = null;
    _drag.value = null;
    final item = hit == null ? null : _c.chart?.item(hit.taskId);
    if (item == null || days == 0) return;
    _do(switch (hit!.mode) {
      DragMode.move => _c.shift(item, days),
      DragMode.resizeStart => _c.resize(item, startEdge: true, days: days),
      DragMode.resizeEnd => _c.resize(item, startEdge: false, days: days),
    });
  }

  // ---- actions ----

  Future<void> _addPhase() async {
    final l = AppLocalizations.of(context);
    final title = await showTitleDialog(context, title: l.gnAddPhase);
    if (title != null) await _do(_c.addPhase(title));
  }

  Future<void> _phaseAction(GanttPhase p, String action) async {
    final l = AppLocalizations.of(context);
    switch (action) {
      case 'rename':
        final t = await showTitleDialog(
          context,
          title: l.gnRename,
          initial: p.title,
        );
        if (t != null) await _do(_c.renamePhase(p.id, t));
      case 'dates':
        final r = await showDatesDialog(
          context,
          title: l.gnSetDates,
          start: p.startAt,
          end: p.endAt,
        );
        if (r != null) await _do(_c.setPhaseDates(p.id, r.start, r.end));
      case 'up':
        await _do(_c.movePhase(p.id, -1));
      case 'down':
        await _do(_c.movePhase(p.id, 1));
      case 'remove':
        final ok = await _confirm(
          l.gnDeactivatePhase,
          l.gnDeactivatePhaseBody(p.title),
        );
        if (ok) await _do(_c.deactivatePhase(p.id));
    }
  }

  Future<void> _taskAction(GanttItem i, String action) async {
    final l = AppLocalizations.of(context);
    switch (action) {
      case 'open':
        await widget.env.openTask?.call(context, i.taskId);
        if (mounted) unawaited(_c.load());
      case 'dates':
        final r = await showDatesDialog(
          context,
          title: l.gnSetDates,
          start: i.start,
          end: i.end,
        );
        if (r != null) await _do(_c.setDates(i.taskId, r.start, r.end));
      case 'deps':
        await showDependenciesDialog(context, _c, i, _report);
      case 'indent':
        await _do(_c.indent(i));
      case 'outdent':
        await _do(_c.outdent(i));
      case 'up':
        await _do(_c.moveTask(i, -1));
      case 'down':
        await _do(_c.moveTask(i, 1));
      case 'phase':
        final id = await showPhasePicker(context, _c.chart!);
        if (id != null) await _do(_c.moveToPhase(i, id < 0 ? null : id));
      case 'remove':
        final ok = await _confirm(
          l.gnRemoveFromPlan,
          l.gnRemoveFromPlanBody(i.title),
        );
        if (ok) await _do(_c.removeFromPlan(i.taskId));
    }
  }

  Future<bool> _confirm(String title, String body) async {
    final l = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.commonCancel),
              ),
              FilledButton(
                key: const ValueKey('gantt-confirm'),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.commonConfirm),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showUnplanned() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => ListenableBuilder(
        listenable: _c,
        builder: (ctx, _) => _UnplannedSheet(
          controller: _c,
          onAdd: (u) async {
            final r = await showAddToPlanDialog(ctx, _c.chart!, u);
            if (r == null) return;
            await _do(
              _c.addToPlan(
                u.taskId,
                phaseId: r.phaseId,
                start: r.start,
                end: r.end,
              ),
            );
          },
        ),
      ),
    );
  }

  void _print() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          GanttPrintScreen(api: widget.env.api, projectId: widget.projectId),
    ),
  );

  // ---- build ----

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _c,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final chart = _c.chart;
      if (chart == null) {
        if (_c.error != null) {
          return EmptyState(
            icon: Icons.cloud_off_outlined,
            title: l.gnLoadFailed,
            message: '${_c.error}',
            action: OutlinedButton.icon(
              onPressed: () => unawaited(_c.load()),
              icon: const Icon(Icons.refresh),
              label: Text(l.commonRetry),
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      }
      return Column(
        children: [
          if (!chart.canEdit) _banner(context, l.gnReadOnly),
          _toolbar(context, chart),
          if (_c.busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _c.rows.isEmpty
                ? EmptyState(
                    icon: Icons.view_timeline_outlined,
                    title: l.gnEmpty,
                    message: chart.canEdit ? l.gnEmptyEdit : null,
                  )
                : _chart(context, chart),
          ),
        ],
      );
    },
  );

  Widget _banner(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('gantt-readonly'),
      width: double.infinity,
      color: scheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.visibility_outlined,
            size: 16,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: scheme.onSecondaryContainer,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context, GanttChart chart) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SegmentedButton<GanttZoom>(
              key: const ValueKey('gantt-zoom'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: GanttZoom.daily,
                  label: Text(l.gnZoomDaily),
                ),
                ButtonSegment(
                  value: GanttZoom.monthly,
                  label: Text(l.gnZoomMonthly),
                ),
                ButtonSegment(
                  value: GanttZoom.quarterly,
                  label: Text(l.gnZoomQuarterly),
                ),
              ],
              selected: {_c.zoom},
              onSelectionChanged: (s) {
                _c.setZoom(s.first);
                _positioned = false;
              },
            ),
            const SizedBox(width: 8),
            if (chart.canEdit) ...[
              TextButton.icon(
                key: const ValueKey('gantt-add-phase'),
                onPressed: _c.busy ? null : _addPhase,
                icon: const Icon(Icons.add),
                label: Text(l.gnAddPhase),
              ),
              TextButton.icon(
                key: const ValueKey('gantt-unplanned'),
                onPressed: _showUnplanned,
                icon: const Icon(Icons.playlist_add),
                label: Text(l.gnUnplanned(chart.unplanned.length.toString())),
              ),
            ],
            IconButton(
              key: const ValueKey('gantt-print'),
              tooltip: l.gnPrint,
              icon: const Icon(Icons.print_outlined),
              onPressed: _print,
            ),
            IconButton(
              tooltip: l.commonRetry,
              icon: const Icon(Icons.refresh),
              onPressed: () => unawaited(_c.load()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chart(BuildContext context, GanttChart chart) {
    final scale = _c.scale;
    final rows = _c.rows;
    final scheme = Theme.of(context).colorScheme;
    final outer = Directionality.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday());
    // Time always runs left to right; the text inside keeps the app's direction.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          SizedBox(
            height: _headerHeight,
            child: Row(
              children: [
                SizedBox(
                  width: _treeWidth,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: scheme.outlineVariant),
                      ),
                    ),
                    child: Text(
                      chart.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: outer,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _header,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: CustomPaint(
                      size: Size(scale.width, _headerHeight),
                      painter: GanttHeaderPainter(
                        scale: scale,
                        color: scheme.onSurfaceVariant,
                        line: scheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _treeWidth,
                    child: Column(
                      children: [
                        for (final row in rows)
                          _treeRow(context, row, chart, outer),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _body,
                      scrollDirection: Axis.horizontal,
                      child: _timeline(scale, rows, chart, scheme),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeline(
    GanttScale scale,
    List<GanttRow> rows,
    GanttChart chart,
    ColorScheme scheme,
  ) {
    final size = Size(scale.width, rows.length * ganttRowHeight);
    final today = asDay(DateTime.now());
    return RawGestureDetector(
      gestures: {
        _BarDragRecognizer:
            GestureRecognizerFactoryWithHandlers<_BarDragRecognizer>(
              _BarDragRecognizer.new,
              (r) {
                r.dragStartBehavior = DragStartBehavior.down;
                r.allow = _probe;
                r.onUpdate = _dragUpdate;
                r.onEnd = (_) => _dragEnd();
                r.onCancel = () => _dragCancel();
              },
            ),
      },
      child: ValueListenableBuilder<BarDrag?>(
        valueListenable: _drag,
        builder: (context, drag, _) => CustomPaint(
          key: const ValueKey('gantt-timeline'),
          size: size,
          painter: GanttTimelinePainter(
            rows: rows,
            links: chart.links,
            scale: scale,
            marks: _c.marks,
            scheme: scheme,
            today: today,
            selected: _c.selected,
            drag: drag,
          ),
        ),
      ),
    );
  }

  Widget _treeRow(
    BuildContext context,
    GanttRow row,
    GanttChart chart,
    TextDirection outer,
  ) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final selected = row.key == _c.selected;
    final item = row.item;
    final phase = row.phase;
    return InkWell(
      key: ValueKey('gantt-row-${row.key}'),
      onTap: () => _c.select(row.key),
      child: Container(
        height: ganttRowHeight,
        padding: EdgeInsetsDirectional.only(start: 6.0 + (row.level - 1) * 14),
        decoration: BoxDecoration(
          color: selected
              ? scheme.secondaryContainer.withValues(alpha: 0.5)
              : null,
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                row.wbs,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: muted, fontSize: 11.5),
              ),
            ),
            Expanded(
              child: Text(
                row.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: outer,
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontWeight: row.isPhase ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 13,
                ),
              ),
            ),
            Text(
              '${row.progress}%',
              style: TextStyle(color: muted, fontSize: 11),
            ),
            PopupMenuButton<String>(
              key: ValueKey('gantt-menu-${row.key}'),
              padding: EdgeInsets.zero,
              iconSize: 18,
              tooltip: l.gnActions,
              onSelected: (a) => unawaited(
                phase != null ? _phaseAction(phase, a) : _taskAction(item!, a),
              ),
              itemBuilder: (_) => _menu(l, row, chart),
            ),
          ],
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _menu(
    AppLocalizations l,
    GanttRow row,
    GanttChart chart,
  ) {
    PopupMenuItem<String> entry(String v, String text) =>
        PopupMenuItem(value: v, child: Text(text));
    final edit = chart.canEdit;
    if (row.isPhase) {
      return [
        if (edit) ...[
          entry('rename', l.gnRename),
          entry('dates', l.gnSetDates),
          entry('up', l.gnMoveUp),
          entry('down', l.gnMoveDown),
          entry('remove', l.gnDeactivatePhase),
        ],
      ];
    }
    return [
      if (widget.env.openTask != null) entry('open', l.gnOpenTask),
      if (edit) ...[
        entry('dates', l.gnSetDates),
        entry('deps', l.gnDependencies),
        entry('indent', l.gnIndent),
        entry('outdent', l.gnOutdent),
        entry('up', l.gnMoveUp),
        entry('down', l.gnMoveDown),
        entry('phase', l.gnMoveToPhase),
        entry('remove', l.gnRemoveFromPlan),
      ],
    ];
  }
}

/// A horizontal drag that only starts where [allow] says a bar is under the finger, so
/// scrolling the chart elsewhere is untouched.
class _BarDragRecognizer extends HorizontalDragGestureRecognizer {
  bool Function(Offset local)? allow;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      (allow?.call(event.localPosition) ?? false) &&
      super.isPointerAllowed(event);
}

class _UnplannedSheet extends StatelessWidget {
  const _UnplannedSheet({required this.controller, required this.onAdd});
  final GanttController controller;
  final Future<void> Function(GanttUnplanned) onAdd;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final list = controller.chart?.unplanned ?? const <GanttUnplanned>[];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: list.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text(l.gnNoUnplanned)),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final u in list)
                    ListTile(
                      key: ValueKey('unplanned-${u.taskId}'),
                      title: Text(
                        u.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: TextButton(
                        key: ValueKey('unplanned-add-${u.taskId}'),
                        onPressed: controller.busy ? null : () => onAdd(u),
                        child: Text(l.gnAddToPlan),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
