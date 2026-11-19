import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/letters/models.dart' show LiveEvent;
import 'package:letter_signing/projects/projects_api.dart';
import 'package:letter_signing/tasks/models.dart';
import 'package:letter_signing/tasks/tasks_api.dart';
import 'package:letter_signing/workspace/subject_controller.dart';

/// State and actions of one open task. Every mutation returns the server's [TaskOut]; a
/// stale `version` (409) or a refusal reloads the task and reports the [ActionOutcome].
class TaskDetailController extends ChangeNotifier {
  TaskDetailController({
    required this.api,
    required this.live,
    required this.taskId,
    required this.projects,
  }) {
    _sub = live.events.listen((e) {
      final t = _task;
      if (t == null || !e.isWorkspace) return;
      if (e.raw['module'] == 'tasks' && e.raw['subject_id'] == t.subjectId) {
        unawaited(reload());
      }
    });
  }

  final TasksApi api;
  final LiveService live;
  final String taskId;
  final ProjectsApi projects;

  StreamSubscription<LiveEvent>? _sub;
  TaskOut? _task;
  Object? _error;
  bool _loading = true;
  bool _busy = false;
  bool _disposed = false;
  Object? _lastError;

  TaskOut? get task => _task;
  Object? get error => _error;
  bool get loading => _loading;

  /// A mutation is in flight (buttons disable).
  bool get busy => _busy;
  Object? get lastError => _lastError;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// First load; marks the task as seen once it arrived.
  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    await reload();
    if (_task != null) unawaited(_markSeen());
  }

  Future<void> _markSeen() async {
    try {
      await api.markSeen(taskId);
    } on Object {
      // Seen-marking is best effort.
    }
  }

  /// Re-reads the task, keeping the shown one when the read fails.
  Future<void> reload() async {
    try {
      _task = await api.get(taskId);
      _error = null;
    } on Object catch (e) {
      if (_task == null) _error = e;
    }
    _loading = false;
    _notify();
  }

  Future<ActionOutcome> _run(Future<TaskOut> Function(TaskOut t) action) async {
    final current = _task;
    if (current == null || _busy) return ActionOutcome.failed;
    _busy = true;
    _notify();
    ActionOutcome outcome;
    try {
      _task = await action(current);
      outcome = ActionOutcome.ok;
    } on Object catch (e) {
      _lastError = e;
      outcome = outcomeOf(e);
      if (outcome != ActionOutcome.failed &&
          outcome != ActionOutcome.notFound) {
        await reload();
      }
    }
    _busy = false;
    _notify();
    return outcome;
  }

  Future<ActionOutcome> complete({String note = ''}) =>
      _run((t) => api.complete(t.id, note: note));

  Future<ActionOutcome> approve({String note = ''}) =>
      _run((t) => api.decide(t.id, 'approve', note: note));

  Future<ActionOutcome> reject(String note) =>
      _run((t) => api.decide(t.id, 'reject', note: note));

  Future<ActionOutcome> reopen() => _run((t) => api.reopen(t.id));

  Future<ActionOutcome> cancel() => _run((t) => api.cancel(t.id));

  /// Moves the task into [columnId] of [projectId] (null project = a personal task again).
  Future<ActionOutcome> move(String? projectId, int? columnId) => _run(
    (t) => projects.move(t.id, projectId: projectId, columnId: columnId),
  );

  /// Copies the task into [projectId] (null = personal); the copy is returned through
  /// [copied]. The shown task does not change.
  Future<ActionOutcome> copyTo(
    String? projectId, {
    required void Function(TaskOut copy) copied,
  }) async {
    try {
      copied(await projects.copyTask(taskId, projectId: projectId));
    } on Object catch (e) {
      _lastError = e;
      return outcomeOf(e);
    }
    return ActionOutcome.ok;
  }

  /// Manual-mode progress, 0..100.
  Future<ActionOutcome> setProgress(int progress) => _run(
    (t) => api.patch(t.id, {
      'progress': progress.clamp(0, 100),
    }, version: t.version),
  );

  Future<ActionOutcome> toggleItem(ChecklistItem item, {required bool done}) =>
      _run((t) => api.patchChecklistItem(t.id, item.id, done: done));

  Future<ActionOutcome> addItem(String text) =>
      _run((t) => api.addChecklistItem(t.id, text.trim()));

  Future<ActionOutcome> removeItem(ChecklistItem item) =>
      _run((t) => api.patchChecklistItem(t.id, item.id, active: false));

  /// Moves an item as `onReorderItem` reports it (`newIndex` already adjusted for the removal).
  Future<ActionOutcome> moveItem(int oldIndex, int newIndex) {
    final ids = [
      for (final i in _task?.checklistItems ?? <ChecklistItem>[]) i.id,
    ];
    if (oldIndex < 0 || oldIndex >= ids.length) {
      return Future.value(ActionOutcome.failed);
    }
    ids.insert(newIndex.clamp(0, ids.length - 1), ids.removeAt(oldIndex));
    return _run((t) => api.reorderChecklist(t.id, ids));
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
