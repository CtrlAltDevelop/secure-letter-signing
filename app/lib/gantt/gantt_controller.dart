import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/gantt/gantt_api.dart';
import 'package:letter_signing/gantt/gantt_models.dart';
import 'package:letter_signing/gantt/gantt_plan.dart';
import 'package:letter_signing/gantt/gantt_scale.dart';

/// State of one project's Gantt chart. Every edit goes to the server and then reloads the
/// chart, so the screen always shows what the server holds; an edit's failure is returned as
/// the server's message (never thrown into the UI).
class GanttController extends ChangeNotifier {
  GanttController(this.api, this.projectId);

  final GanttApi api;
  final String projectId;

  GanttChart? chart;
  GanttCalendarMarks marks = const GanttCalendarMarks();
  Object? error;
  bool loading = false;
  bool busy = false;
  GanttZoom zoom = GanttZoom.daily;
  String? selected;
  bool _disposed = false;

  bool get canEdit => chart?.canEdit ?? false;
  List<GanttRow> get rows => chart == null ? const [] : chartRows(chart!);

  GanttScale get scale => GanttScale.fit(chart?.start, chart?.end, zoom);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      chart = await api.chart(projectId);
      unawaited(_loadMarks());
    } on Object catch (e) {
      error = e;
    }
    loading = false;
    notifyListeners();
  }

  /// Weekend and holiday shading; the chart works without it.
  Future<void> _loadMarks() async {
    try {
      marks = (await api.print(projectId)).marks;
      notifyListeners();
    } on Object {
      // Shading is a nicety.
    }
  }

  void setZoom(GanttZoom z) {
    if (z == zoom) return;
    zoom = z;
    notifyListeners();
  }

  void select(String? key) {
    selected = key == selected ? null : key;
    notifyListeners();
  }

  /// Runs one edit then reloads. Returns the failure message, or null on success.
  Future<String?> run(Future<void> Function() edit) async {
    if (busy) return null;
    busy = true;
    notifyListeners();
    String? failure;
    try {
      await edit();
      chart = await api.chart(projectId);
    } on ApiException catch (e) {
      failure = e.message;
    } on Object catch (e) {
      failure = '$e';
    }
    busy = false;
    notifyListeners();
    return failure;
  }

  // ---- phases ----

  Future<String?> addPhase(String title, {DateTime? start, DateTime? end}) =>
      run(
        () => api.createPhase(projectId, title: title, start: start, end: end),
      );

  Future<String?> renamePhase(int id, String title) =>
      run(() => api.patchPhase(projectId, id, title: title));

  Future<String?> setPhaseDates(int id, DateTime? start, DateTime? end) => run(
    () => api.patchPhase(projectId, id, setDates: true, start: start, end: end),
  );

  Future<String?> deactivatePhase(int id) =>
      run(() => api.patchPhase(projectId, id, active: false));

  Future<String?> movePhase(int id, int delta) {
    final order = chart == null ? null : movePhases(chart!, id, delta);
    if (order == null) return Future.value(null);
    return _reorder(phaseIds: order);
  }

  // ---- tasks ----

  Future<String?> _put(String taskId, Map<String, Object?> body) =>
      run(() => api.putItem(projectId, taskId, body));

  Future<String?> addToPlan(
    String taskId, {
    int? phaseId,
    DateTime? start,
    DateTime? end,
  }) => _put(taskId, {
    'phase_id': phaseId,
    if (start != null) 'start_at': dayString(start),
    if (end != null) 'end_at': dayString(end),
  });

  Future<String?> setDates(String taskId, DateTime? start, DateTime? end) =>
      _put(taskId, {
        'start_at': start == null ? null : dayString(start),
        'end_at': end == null ? null : dayString(end),
      });

  Future<String?> shift(GanttItem item, int days) => days == 0 || !item.hasBar
      ? Future.value(null)
      : _put(item.taskId, shiftBody(item, days));

  Future<String?> resize(
    GanttItem item, {
    required bool startEdge,
    required int days,
  }) => days == 0 || !item.hasBar
      ? Future.value(null)
      : _put(item.taskId, resizeBody(item, startEdge: startEdge, days: days));

  Future<String?> indent(GanttItem item) {
    final body = chart == null ? null : indentBody(chart!, item);
    return body == null ? Future.value(null) : _put(item.taskId, body);
  }

  Future<String?> outdent(GanttItem item) {
    final body = chart == null ? null : outdentBody(chart!, item);
    return body == null ? Future.value(null) : _put(item.taskId, body);
  }

  /// Puts a task directly under [phaseId] (null: top level).
  Future<String?> moveToPhase(GanttItem item, int? phaseId) =>
      _put(item.taskId, {'phase_id': phaseId, 'parent_task_id': null});

  Future<String?> moveTask(GanttItem item, int delta) {
    final items = chart == null ? null : moveItems(chart!, item, delta);
    return items == null ? Future.value(null) : _reorder(items: items);
  }

  Future<String?> removeFromPlan(String taskId) =>
      _put(taskId, {'active': false});

  Future<String?> _reorder({
    List<int>? phaseIds,
    List<Map<String, Object?>>? items,
  }) async {
    if (busy) return null;
    busy = true;
    notifyListeners();
    String? failure;
    try {
      chart = await api.reorder(projectId, phaseIds: phaseIds, items: items);
    } on ApiException catch (e) {
      failure = e.message;
    } on Object catch (e) {
      failure = '$e';
    }
    busy = false;
    notifyListeners();
    return failure;
  }

  // ---- dependencies ----

  Future<String?> addLink(String predecessorId, String successorId) => run(
    () => api.addLink(
      projectId,
      predecessorId: predecessorId,
      successorId: successorId,
    ),
  );

  Future<String?> removeLink(int linkId) =>
      run(() => api.deactivateLink(projectId, linkId));
}
