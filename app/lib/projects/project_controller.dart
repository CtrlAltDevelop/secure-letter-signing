import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:letter_signing/letters/models.dart' show LiveEvent;
import 'package:letter_signing/projects/models.dart';
import 'package:letter_signing/projects/projects_env.dart';
import 'package:letter_signing/tasks/models.dart';
import 'package:letter_signing/workspace/subject_controller.dart'
    show ActionOutcome, outcomeOf;

/// How a board column orders its cards on screen. [manual] is the server rank; the others sort
/// the loaded column on the client. The brief has no creation time, so `created` falls back to
/// the rank (new cards are appended); `due` stands in for the reminder date.
enum ColumnSort {
  manual,
  createdAsc,
  createdDesc,
  dueAsc,
  dueDesc,
  updatedAsc,
  updatedDesc,
}

/// The tasks of [tasks] ordered by [sort] (a new list).
List<TaskBrief> sortTasks(List<TaskBrief> tasks, ColumnSort sort) {
  final out = [...tasks];
  int byRank(TaskBrief a, TaskBrief b) => a.rank.compareTo(b.rank);
  int byDue(TaskBrief a, TaskBrief b) {
    final x = a.dueAt, y = b.dueAt;
    if (x == null || y == null) {
      return x == y ? 0 : (x == null ? 1 : -1);
    }
    return x.compareTo(y);
  }

  int byUpdated(TaskBrief a, TaskBrief b) {
    final x = a.updatedAt, y = b.updatedAt;
    if (x == null || y == null) return x == y ? 0 : (x == null ? -1 : 1);
    return x.compareTo(y);
  }

  switch (sort) {
    case ColumnSort.manual:
    case ColumnSort.createdAsc:
      out.sort(byRank);
    case ColumnSort.createdDesc:
      out.sort((a, b) => byRank(b, a));
    case ColumnSort.dueAsc:
      out.sort(byDue);
    case ColumnSort.dueDesc:
      // Tasks without a date stay last in both directions.
      out.sort((a, b) {
        if (a.dueAt == null || b.dueAt == null) return byDue(a, b);
        return byDue(b, a);
      });
    case ColumnSort.updatedAsc:
      out.sort(byUpdated);
    case ColumnSort.updatedDesc:
      out.sort((a, b) => byUpdated(b, a));
  }
  return out;
}

/// The board after dragging [taskId] to [toColumnId], just before [beforeId] (null = the end).
/// Returns [columns] unchanged when the task or column is unknown.
List<BoardColumn> applyMove(
  List<BoardColumn> columns,
  String taskId,
  int toColumnId, {
  String? beforeId,
}) {
  TaskBrief? moved;
  for (final c in columns) {
    for (final t in c.tasks) {
      if (t.id == taskId) moved = t;
    }
  }
  if (moved == null || !columns.any((c) => c.id == toColumnId)) return columns;
  final task = moved.copyWithColumn(toColumnId);
  return [
    for (final c in columns)
      c.copyWith(
        tasks: [
          for (final t in c.tasks)
            if (t.id != taskId) t,
        ],
      ),
  ].map((c) {
    if (c.id != toColumnId) return c;
    final list = [...c.tasks];
    final at = beforeId == null
        ? list.length
        : list.indexWhere((t) => t.id == beforeId);
    list.insert(at < 0 ? list.length : at, task);
    return c.copyWith(tasks: list);
  }).toList();
}

/// State of one open project: the project itself and its board (with optimistic moves,
/// per-column sorting, compact cards and the manager's column edits).
class ProjectController extends ChangeNotifier {
  ProjectController({required this.env, required this.projectId}) {
    _sub = env.live.events.listen((e) {
      if (!e.isWorkspace) return;
      final module = e.raw['module'];
      if (module == 'projects' || module == 'tasks') unawaited(reloadBoard());
    });
  }

  final ProjectsEnv env;
  final String projectId;

  StreamSubscription<LiveEvent>? _sub;
  ProjectOut? _project;
  List<BoardColumn> _board = const [];
  final Map<int, ColumnSort> _sorts = {};
  bool _compact = false;
  bool _loading = true;
  bool _disposed = false;
  int _pendingMoves = 0;
  Object? _error;
  Object? _lastError;

  ProjectOut? get project => _project;
  List<BoardColumn> get board => _board;
  bool get compact => _compact;
  bool get loading => _loading;
  Object? get error => _error;
  Object? get lastError => _lastError;

  /// A project manager (role) may sort columns and edit them.
  bool get isManager => _project?.isManager ?? false;

  ColumnSort sortOf(int columnId) => _sorts[columnId] ?? ColumnSort.manual;

  /// The cards of [column] in the order they are shown.
  List<TaskBrief> shown(BoardColumn column) =>
      sortTasks(column.tasks, sortOf(column.id));

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setCompact({required bool value}) {
    _compact = value;
    _notify();
  }

  void setSort(int columnId, ColumnSort sort) {
    _sorts[columnId] = sort;
    _notify();
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      final results = await Future.wait([
        env.api.get(projectId),
        env.api.board(projectId),
      ]);
      _project = results[0] as ProjectOut;
      _board = results[1] as List<BoardColumn>;
    } on Object catch (e) {
      _error = e;
    }
    _loading = false;
    _notify();
  }

  /// Re-reads project and board without flicker; skipped while a move is in flight so a
  /// live event cannot undo the optimistic state.
  Future<void> reloadBoard() async {
    if (_pendingMoves > 0 || _loading) return;
    try {
      final project = await env.api.get(projectId);
      final board = await env.api.board(projectId);
      if (_pendingMoves > 0) return;
      _project = project;
      _board = board;
      _notify();
    } on Object catch (e) {
      _lastError = e;
    }
  }

  /// Drops [task] into [columnId] before [beforeId]. The board changes at once; a failure
  /// restores the previous board and reports the outcome.
  Future<ActionOutcome> moveTask(
    TaskBrief task,
    int columnId, {
    String? beforeId,
  }) async {
    if (beforeId == task.id) return ActionOutcome.ok;
    final snapshot = _board;
    final next = applyMove(snapshot, task.id, columnId, beforeId: beforeId);
    if (identical(next, snapshot)) return ActionOutcome.failed;
    _board = next;
    _pendingMoves++;
    _notify();
    try {
      final saved = await env.api.move(
        task.id,
        projectId: projectId,
        columnId: columnId,
        beforeId: beforeId,
      );
      _board = _replace(_board, saved);
    } on Object catch (e) {
      _lastError = e;
      _board = snapshot;
      _pendingMoves--;
      _notify();
      return outcomeOf(e);
    }
    _pendingMoves--;
    _notify();
    return ActionOutcome.ok;
  }

  static List<BoardColumn> _replace(List<BoardColumn> board, TaskBrief saved) =>
      [
        for (final c in board)
          c.copyWith(
            tasks: [for (final t in c.tasks) t.id == saved.id ? saved : t],
          ),
      ];

  /// Adds a task titled [title] to [columnId], owned by the current user.
  Future<ActionOutcome> addTask(int columnId, String title) async {
    final draft = TaskDraft(
      title: title,
      ownerIds: [env.userId],
      projectId: projectId,
      columnId: columnId,
    );
    try {
      await env.tasks.api.create(draft);
    } on Object catch (e) {
      _lastError = e;
      return outcomeOf(e);
    }
    await reloadBoard();
    return ActionOutcome.ok;
  }

  Future<ActionOutcome> _columnAction(Future<Object?> Function() action) async {
    try {
      await action();
    } on Object catch (e) {
      _lastError = e;
      return outcomeOf(e);
    }
    await reloadBoard();
    return ActionOutcome.ok;
  }

  Future<ActionOutcome> addColumn(String title) =>
      _columnAction(() => env.api.addColumn(projectId, title.trim()));

  Future<ActionOutcome> renameColumn(int id, String title) => _columnAction(
    () => env.api.patchColumn(projectId, id, title: title.trim()),
  );

  /// Hides an empty column (the server refuses the last or a non-empty one with 409).
  Future<ActionOutcome> hideColumn(int id) =>
      _columnAction(() => env.api.patchColumn(projectId, id, active: false));

  /// Moves a column one place left (-1) or right (+1) in the displayed order.
  Future<ActionOutcome> shiftColumn(int id, int delta) {
    final ids = [for (final c in _board) c.id];
    final from = ids.indexOf(id);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= ids.length) {
      return Future.value(ActionOutcome.failed);
    }
    ids.insert(to, ids.removeAt(from));
    return _columnAction(() => env.api.reorderColumns(projectId, ids));
  }

  /// Archives, completes or reactivates the project.
  Future<ActionOutcome> setStatus(String status) async {
    try {
      _project = await env.api.patch(projectId, {'status': status});
    } on Object catch (e) {
      _lastError = e;
      return outcomeOf(e);
    }
    _notify();
    return ActionOutcome.ok;
  }

  /// Copies this project with its structure; the copy comes back through [copied].
  Future<ActionOutcome> copyProject(
    String name, {
    required void Function(ProjectOut copy) copied,
  }) async {
    try {
      copied(await env.api.copyProject(projectId, name.trim()));
    } on Object catch (e) {
      _lastError = e;
      return outcomeOf(e);
    }
    return ActionOutcome.ok;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
