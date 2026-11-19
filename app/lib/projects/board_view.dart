import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/projects/board_cards.dart';
import 'package:letter_signing/projects/models.dart';
import 'package:letter_signing/projects/project_controller.dart';
import 'package:letter_signing/projects/project_ui.dart';
import 'package:letter_signing/tasks/models.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';

/// The Kanban board: columns side by side (scrolling horizontally), cards that can be dragged
/// between and within columns (long press, then drag), per-column progress, a compact-card
/// switch, and for project managers sorting and column editing.
class BoardView extends StatefulWidget {
  const BoardView({
    super.key,
    required this.controller,
    required this.onOpenTask,
    this.labels = const [],
  });

  final ProjectController controller;
  final ValueChanged<String> onOpenTask;
  final List<LabelInfo> labels;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> {
  static const _edgeZone = 48.0;
  static const _edgeStep = 16.0;
  final _scroll = ScrollController();

  ProjectController get _c => widget.controller;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool get _canDrag {
    final p = _c.project;
    return p != null && p.myRole != ProjectRole.viewer && !p.isArchived;
  }

  Future<void> _drop(TaskBrief task, int columnId, String? beforeId) async {
    final outcome = await _c.moveTask(task, columnId, beforeId: beforeId);
    if (mounted) reportOutcome(context, outcome, _c.lastError);
  }

  /// Scrolls the board while a card is held near its left or right edge.
  void _autoScroll(Offset global) {
    if (!_scroll.hasClients) return;
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final x = box.globalToLocal(global).dx;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    var step = 0.0;
    if (x < _edgeZone) step = -_edgeStep;
    if (x > box.size.width - _edgeZone) step = _edgeStep;
    if (step == 0) return;
    final delta = rtl ? -step : step;
    final pos = _scroll.position;
    _scroll.jumpTo(
      (pos.pixels + delta).clamp(pos.minScrollExtent, pos.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _c,
    builder: (context, _) => Column(
      children: [
        _toolbar(context),
        Expanded(child: _columns(context)),
      ],
    ),
  );

  Widget _toolbar(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Tokens.gap,
        4,
        Tokens.gap,
        0,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilterChip(
            key: const ValueKey('compact-toggle'),
            label: Text(l.boardCompact),
            avatar: const Icon(Icons.view_agenda_outlined, size: 18),
            selected: _c.compact,
            visualDensity: VisualDensity.compact,
            onSelected: (v) => _c.setCompact(value: v),
          ),
          if (_c.isManager && !(_c.project?.isArchived ?? true))
            TextButton.icon(
              key: const ValueKey('add-column'),
              onPressed: () => unawaited(_addColumn()),
              icon: const Icon(Icons.view_column_outlined),
              label: Text(l.columnAdd),
            ),
        ],
      ),
    );
  }

  Future<void> _addColumn() async {
    final l = AppLocalizations.of(context);
    final title = await showTextPrompt(
      context,
      title: l.columnAdd,
      confirmLabel: l.commonSave,
      hint: l.columnTitleHint,
    );
    if (title == null || !mounted) return;
    final outcome = await _c.addColumn(title);
    if (mounted) reportOutcome(context, outcome, _c.lastError);
  }

  Widget _columns(BuildContext context) {
    final board = _c.board;
    if (board.isEmpty) {
      return EmptyState(
        icon: Icons.view_kanban_outlined,
        title: AppLocalizations.of(context).boardEmpty,
      );
    }
    final width = math.min(300.0, MediaQuery.sizeOf(context).width * 0.82);
    return ListView.separated(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.fromSTEB(
        Tokens.gap,
        8,
        Tokens.gap,
        12,
      ),
      itemCount: board.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (context, i) => SizedBox(
        width: width,
        child: BoardColumnView(
          key: ValueKey('column-${board[i].id}'),
          controller: _c,
          column: board[i],
          index: i,
          labels: widget.labels,
          canDrag: _canDrag,
          onOpenTask: widget.onOpenTask,
          onDrop: _drop,
          onDragUpdate: _autoScroll,
        ),
      ),
    );
  }
}

/// One column: header with its menu, the draggable cards and the inline "add task" row.
class BoardColumnView extends StatefulWidget {
  const BoardColumnView({
    super.key,
    required this.controller,
    required this.column,
    required this.index,
    required this.labels,
    required this.canDrag,
    required this.onOpenTask,
    required this.onDrop,
    required this.onDragUpdate,
  });

  final ProjectController controller;
  final BoardColumn column;
  final int index;
  final List<LabelInfo> labels;
  final bool canDrag;
  final ValueChanged<String> onOpenTask;
  final Future<void> Function(TaskBrief task, int columnId, String? beforeId)
  onDrop;
  final ValueChanged<Offset> onDragUpdate;

  @override
  State<BoardColumnView> createState() => _BoardColumnViewState();
}

class _BoardColumnViewState extends State<BoardColumnView> {
  final _newTask = TextEditingController();
  bool _adding = false;

  ProjectController get _c => widget.controller;
  BoardColumn get _col => widget.column;

  @override
  void dispose() {
    _newTask.dispose();
    super.dispose();
  }

  Future<void> _submitTask() async {
    final title = _newTask.text.trim();
    if (title.isEmpty) return;
    _newTask.clear();
    final outcome = await _c.addTask(_col.id, title);
    if (mounted) reportOutcome(context, outcome, _c.lastError);
  }

  Future<void> _rename() async {
    final l = AppLocalizations.of(context);
    final title = await showTextPrompt(
      context,
      title: l.columnRename,
      confirmLabel: l.commonSave,
      initial: _col.title,
    );
    if (title == null || !mounted) return;
    final outcome = await _c.renameColumn(_col.id, title);
    if (mounted) reportOutcome(context, outcome, _c.lastError);
  }

  Future<void> _menu(String action) async {
    if (action == 'rename') return _rename();
    final outcome = switch (action) {
      'hide' => await _c.hideColumn(_col.id),
      'earlier' => await _c.shiftColumn(_col.id, -1),
      _ => await _c.shiftColumn(_col.id, 1),
    };
    if (mounted) reportOutcome(context, outcome, _c.lastError);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(Tokens.radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            ColumnHeaderInfo(
              title: _col.title,
              count: _col.tasks.length,
              percent: _col.percentDone,
              trailing: [
                if (_c.isManager) _sortButton(context),
                if (_c.isManager) _menuButton(context),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(child: _cards(context)),
            if (_c.project?.can.createTask ?? false) _addRow(context),
          ],
        ),
      ),
    );
  }

  Widget _sortButton(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopupMenuButton<ColumnSort>(
      key: ValueKey('col-sort-${_col.id}'),
      tooltip: l.columnSort,
      icon: Icon(
        Icons.sort,
        size: 20,
        color: _c.sortOf(_col.id) == ColumnSort.manual
            ? null
            : Theme.of(context).colorScheme.primary,
      ),
      padding: EdgeInsets.zero,
      onSelected: (s) => _c.setSort(_col.id, s),
      itemBuilder: (_) => [
        for (final s in ColumnSort.values)
          CheckedPopupMenuItem(
            value: s,
            checked: _c.sortOf(_col.id) == s,
            child: Text(columnSortLabel(l, s)),
          ),
      ],
    );
  }

  Widget _menuButton(BuildContext context) {
    final l = AppLocalizations.of(context);
    final last = widget.index == _c.board.length - 1;
    return PopupMenuButton<String>(
      key: ValueKey('col-menu-${_col.id}'),
      tooltip: l.columnMenu,
      padding: EdgeInsets.zero,
      onSelected: (a) => unawaited(_menu(a)),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'rename', child: Text(l.columnRename)),
        PopupMenuItem(value: 'hide', child: Text(l.columnHide)),
        if (widget.index > 0)
          PopupMenuItem(value: 'earlier', child: Text(l.columnMoveEarlier)),
        if (!last)
          PopupMenuItem(value: 'later', child: Text(l.columnMoveLater)),
      ],
    );
  }

  Widget _cards(BuildContext context) {
    final tasks = _c.shown(_col);
    return DragTarget<TaskBrief>(
      key: ValueKey('drop-end-${_col.id}'),
      onWillAcceptWithDetails: (_) => widget.canDrag,
      onAcceptWithDetails: (d) =>
          unawaited(widget.onDrop(d.data, _col.id, null)),
      builder: (context, candidates, _) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Tokens.radiusSmall),
          border: candidates.isEmpty
              ? null
              : Border.all(color: Theme.of(context).colorScheme.primary),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            for (final t in tasks) _card(context, t),
            if (tasks.isEmpty)
              const SizedBox(height: 72, width: double.infinity),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, TaskBrief task) {
    final card = BoardCard(
      task: task,
      labels: widget.labels,
      compact: _c.compact,
      onTap: () => widget.onOpenTask(task.id),
    );
    return DragTarget<TaskBrief>(
      key: ValueKey('drop-before-${task.id}'),
      onWillAcceptWithDetails: (d) => widget.canDrag && d.data.id != task.id,
      onAcceptWithDetails: (d) =>
          unawaited(widget.onDrop(d.data, _col.id, task.id)),
      builder: (context, candidates, _) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (candidates.isNotEmpty) _dropMark(context),
            if (widget.canDrag) _draggable(task, card) else card,
          ],
        ),
      ),
    );
  }

  Widget _dropMark(BuildContext context) => Container(
    key: const ValueKey('drop-mark'),
    height: 4,
    margin: const EdgeInsets.only(bottom: 6),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary,
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _draggable(TaskBrief task, Widget card) =>
      LongPressDraggable<TaskBrief>(
        key: ValueKey('drag-${task.id}'),
        data: task,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        onDragUpdate: (d) => widget.onDragUpdate(d.globalPosition),
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: 260,
            child: Opacity(opacity: 0.92, child: card),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: card),
        child: card,
      );

  Widget _addRow(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (!_adding) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          key: ValueKey('add-task-${_col.id}'),
          onPressed: () => setState(() => _adding = true),
          icon: const Icon(Icons.add, size: 18),
          label: Text(l.boardAddTask),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: ValueKey('add-task-field-${_col.id}'),
            controller: _newTask,
            autofocus: true,
            decoration: InputDecoration(hintText: l.boardAddTaskHint),
            onSubmitted: (_) => unawaited(_submitTask()),
          ),
        ),
        IconButton(
          tooltip: l.commonSave,
          icon: const Icon(Icons.check),
          onPressed: () => unawaited(_submitTask()),
        ),
        IconButton(
          tooltip: l.commonCancel,
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _adding = false),
        ),
      ],
    );
  }
}
