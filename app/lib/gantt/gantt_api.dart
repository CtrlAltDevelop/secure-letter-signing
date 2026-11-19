import 'package:letter_signing/gantt/gantt_models.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// Typed access to `/projects/{id}/gantt/*`. 403 = no edit right, 404 = no such project or the
/// module is off, 422 = a rule (cycle, bad dates) -- all with the server's message.
class GanttApi {
  GanttApi(this.workspace);

  final WorkspaceApi workspace;

  String _base(String projectId) => '/projects/$projectId/gantt';

  Future<GanttChart> chart(String projectId) async =>
      GanttChart.fromJson(asMap(await workspace.call('GET', _base(projectId))));

  /// Weekend, holidays and flat rows for printing.
  Future<GanttPrint> print(String projectId) async => GanttPrint.fromJson(
    asMap(await workspace.call('GET', '${_base(projectId)}/print')),
  );

  Future<void> createPhase(
    String projectId, {
    required String title,
    DateTime? start,
    DateTime? end,
  }) => workspace.call(
    'POST',
    '${_base(projectId)}/phases',
    body: {
      'title': title,
      if (start != null) 'start_at': dayString(start),
      if (end != null) 'end_at': dayString(end),
    },
  );

  /// Only the given fields change; [setDates] says the dates are meant (null clears them).
  Future<void> patchPhase(
    String projectId,
    int phaseId, {
    String? title,
    bool setDates = false,
    DateTime? start,
    DateTime? end,
    bool? active,
  }) => workspace.call(
    'PATCH',
    '${_base(projectId)}/phases/$phaseId',
    body: {
      'title': ?title,
      if (setDates) ...{
        'start_at': start == null ? null : dayString(start),
        'end_at': end == null ? null : dayString(end),
      },
      'active': ?active,
    },
  );

  /// Puts a task into the plan or changes its row. [body] is sent as is, so `null` values
  /// (top level, cleared dates) are real "set to nothing" requests.
  Future<void> putItem(
    String projectId,
    String taskId,
    Map<String, Object?> body,
  ) => workspace.call('PUT', '${_base(projectId)}/items/$taskId', body: body);

  Future<void> addLink(
    String projectId, {
    required String predecessorId,
    required String successorId,
  }) => workspace.call(
    'POST',
    '${_base(projectId)}/links',
    body: {
      'predecessor_task_id': predecessorId,
      'successor_task_id': successorId,
    },
  );

  Future<void> deactivateLink(String projectId, int linkId) =>
      workspace.call('POST', '${_base(projectId)}/links/$linkId/deactivate');

  /// Returns the whole chart as the server now has it.
  Future<GanttChart> reorder(
    String projectId, {
    List<int>? phaseIds,
    List<Map<String, Object?>>? items,
  }) async => GanttChart.fromJson(
    asMap(
      await workspace.call(
        'POST',
        '${_base(projectId)}/reorder',
        body: {'phase_ids': ?phaseIds, 'items': ?items},
      ),
    ),
  );
}
