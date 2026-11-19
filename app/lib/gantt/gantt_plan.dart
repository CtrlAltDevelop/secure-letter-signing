import 'package:letter_signing/gantt/gantt_models.dart';

/// Pure planning rules behind the edit actions, so they can be tested without widgets.

/// `{phase_id, parent_task_id}` placement of a task.
typedef Placement = ({int? phaseId, String? parentId});

Placement placementOf(GanttItem i) =>
    (phaseId: i.phaseId, parentId: i.parentTaskId);

/// Tasks sharing [item]'s phase and parent, in chart order.
List<GanttItem> siblingsOf(GanttChart chart, GanttItem item) => [
  for (final i in chart.items)
    if (i.parentTaskId == item.parentTaskId &&
        (item.parentTaskId != null || i.phaseId == item.phaseId))
      i,
];

/// Body of the PUT that nests [item] under the sibling right above it, or null when it is first.
Map<String, Object?>? indentBody(GanttChart chart, GanttItem item) {
  final sibs = siblingsOf(chart, item);
  final at = sibs.indexWhere((s) => s.taskId == item.taskId);
  if (at <= 0) return null;
  return {'parent_task_id': sibs[at - 1].taskId};
}

/// Body of the PUT that lifts [item] to its parent's level, or null when it is already top level.
Map<String, Object?>? outdentBody(GanttChart chart, GanttItem item) {
  final parent = item.parentTaskId == null
      ? null
      : chart.item(item.parentTaskId!);
  if (parent == null) return null;
  return {'phase_id': parent.phaseId, 'parent_task_id': parent.parentTaskId};
}

/// `items` list for `POST /reorder`: [item]'s siblings with it moved by [delta] places
/// (-1 up, +1 down), or null when it cannot move that way.
List<Map<String, Object?>>? moveItems(
  GanttChart chart,
  GanttItem item,
  int delta,
) {
  final sibs = siblingsOf(chart, item);
  final from = sibs.indexWhere((s) => s.taskId == item.taskId);
  final to = from + delta;
  if (from < 0 || to < 0 || to >= sibs.length) return null;
  final order = [...sibs]
    ..removeAt(from)
    ..insert(to, item);
  return [
    for (final s in order)
      {
        'task_id': s.taskId,
        'phase_id': s.phaseId,
        'parent_task_id': s.parentTaskId,
      },
  ];
}

/// New order of every active phase after moving [phaseId] by [delta], or null.
List<int>? movePhases(GanttChart chart, int phaseId, int delta) {
  final ids = [
    for (final p in chart.phases)
      if (p.active) p.id,
  ];
  final from = ids.indexOf(phaseId);
  final to = from + delta;
  if (from < 0 || to < 0 || to >= ids.length) return null;
  return [...ids]
    ..removeAt(from)
    ..insert(to, phaseId);
}

/// [item]'s dates moved by [days] (both ends), as the PUT body.
Map<String, Object?> shiftBody(GanttItem item, int days) => {
  'start_at': dayString(item.start!.add(Duration(days: days))),
  'end_at': dayString(item.end!.add(Duration(days: days))),
};

/// Resizing an edge by [days]; the other edge stays, and the bar never shrinks below one day.
Map<String, Object?> resizeBody(
  GanttItem item, {
  required bool startEdge,
  required int days,
}) {
  var start = item.start!;
  var end = item.end!;
  if (startEdge) {
    start = start.add(Duration(days: days));
    if (start.isAfter(end)) start = end;
  } else {
    end = end.add(Duration(days: days));
    if (end.isBefore(start)) end = start;
  }
  return {'start_at': dayString(start), 'end_at': dayString(end)};
}

/// Tasks that may become predecessors of [taskId]: planned tasks that are not it and not
/// already linked to it.
List<GanttItem> predecessorCandidates(GanttChart chart, String taskId) {
  final linked = {
    for (final l in chart.links)
      if (l.successorId == taskId) l.predecessorId,
  };
  return [
    for (final i in chart.items)
      if (i.taskId != taskId && !linked.contains(i.taskId)) i,
  ];
}
