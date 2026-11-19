import 'package:letter_signing/calendar/models.dart';
import 'package:letter_signing/tasks/models.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// Typed access to `/calendar` and `/tasks/of/{user_id}`. 403 (no `monitor.view`) is a
/// [ForbiddenException].
class CalendarApi {
  CalendarApi(this.workspace);

  final WorkspaceApi workspace;

  /// [from] inclusive, [to] exclusive, at most 100 days apart.
  Future<CalendarData> calendar(
    DateTime from,
    DateTime to, {
    CalendarFilter filter = const CalendarFilter(),
  }) async {
    final q = WorkspaceApi.query({
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
      'project': filter.projectId,
      'customer': filter.customerId,
      'label': filter.labelId,
      'owner': filter.team ? null : filter.ownerId,
      'team': filter.team ? 'true' : null,
      'user': filter.team ? filter.ownerId : null,
    });
    return CalendarData.fromJson(await workspace.call('GET', '/calendar$q'));
  }

  /// A colleague's active tasks (`monitor.view`): [box] is `inbox` or `followup`.
  Future<List<TaskBrief>> tasksOf(
    int userId, {
    String box = 'inbox',
    int limit = 50,
    int offset = 0,
  }) async {
    final q = WorkspaceApi.query({
      'box': box,
      'limit': limit,
      'offset': offset,
    });
    final data = await workspace.call('GET', '/tasks/of/$userId$q');
    return [for (final j in asMapList(data)) TaskBrief.fromJson(j)];
  }
}
