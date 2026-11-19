import 'package:letter_signing/projects/models.dart';
import 'package:letter_signing/tasks/models.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// Typed access to `/projects`, `/project-groups` and the task move/copy calls. Errors
/// 403/404/409 are typed exceptions.
class ProjectsApi {
  ProjectsApi(this.workspace);

  final WorkspaceApi workspace;

  Future<Map<String, dynamic>> _map(
    String method,
    String path, {
    Object? body,
  }) async => asMap(await workspace.call(method, path, body: body));

  Future<ProjectOut> _project(
    String method,
    String path, {
    Object? body,
  }) async => ProjectOut.fromJson(await _map(method, path, body: body));

  Future<List<ProjectBrief>> list({
    int? group,
    String status = '',
    String q = '',
  }) async {
    final params = WorkspaceApi.query({
      'group': group,
      'status': status,
      'q': q,
    });
    final data = await workspace.call('GET', '/projects$params');
    return [for (final j in asMapList(data)) ProjectBrief.fromJson(j)];
  }

  Future<ProjectOut> get(String id) => _project('GET', '/projects/$id');

  Future<ProjectOut> create(ProjectDraft draft) =>
      _project('POST', '/projects', body: draft.toCreateJson());

  Future<ProjectOut> patch(String id, Map<String, dynamic> fields) =>
      _project('PATCH', '/projects/$id', body: fields);

  /// Replaces the members (the server takes the bare list as body).
  Future<ProjectOut> setMembers(String id, List<MemberDraft> members) =>
      _project(
        'PUT',
        '/projects/$id/members',
        body: [for (final m in members) m.toJson()],
      );

  Future<List<ProjectColumn>> addColumn(
    String id,
    String title, {
    String kind = ColumnKind.doing,
  }) async => ProjectColumn.parseAll(
    await workspace.call(
      'POST',
      '/projects/$id/columns',
      body: {'title': title, 'kind': kind},
    ),
  );

  /// Renames ([title]) or hides ([active] false) a column.
  Future<List<ProjectColumn>> patchColumn(
    String id,
    int columnId, {
    String? title,
    bool? active,
  }) async => ProjectColumn.parseAll(
    await workspace.call(
      'PATCH',
      '/projects/$id/columns/$columnId',
      body: {'title': ?title, 'active': ?active},
    ),
  );

  Future<List<ProjectColumn>> reorderColumns(
    String id,
    List<int> columnIds,
  ) async => ProjectColumn.parseAll(
    await workspace.call(
      'PUT',
      '/projects/$id/columns/order',
      body: {'ids': columnIds},
    ),
  );

  /// The board view: every visible column with its tasks.
  Future<List<BoardColumn>> board(
    String id, {
    String q = '',
    String status = '',
    int? owner,
    int? label,
  }) async {
    final params = WorkspaceApi.query({
      'view': 'board',
      'q': q,
      'status': status,
      'owner': owner,
      'label': label,
    });
    final data = asMap(
      await workspace.call('GET', '/projects/$id/tasks$params'),
    );
    return [
      for (final c in asMapList(data['columns'])) BoardColumn.fromJson(c),
    ];
  }

  /// The flat `list` or `calendar` view ([from]/[to] bound the calendar by due date).
  Future<List<TaskBrief>> tasks(
    String id, {
    String view = 'list',
    DateTime? from,
    DateTime? to,
    String q = '',
    String status = '',
    int? owner,
    int? label,
  }) async {
    final params = WorkspaceApi.query({
      'view': view,
      'from': from?.toUtc().toIso8601String(),
      'to': to?.toUtc().toIso8601String(),
      'q': q,
      'status': status,
      'owner': owner,
      'label': label,
    });
    final data = asMap(
      await workspace.call('GET', '/projects/$id/tasks$params'),
    );
    return [for (final t in asMapList(data['tasks'])) TaskBrief.fromJson(t)];
  }

  /// Places a task into [columnId] of [projectId] just before [beforeId] (null = at the end).
  Future<TaskOut> move(
    String taskId, {
    required String? projectId,
    int? columnId,
    String? beforeId,
  }) async => TaskOut.fromJson(
    await _map(
      'POST',
      '/tasks/$taskId/move',
      body: {
        'project_id': projectId,
        'column_id': columnId,
        'before_id': beforeId,
      },
    ),
  );

  Future<TaskOut> copyTask(String taskId, {required String? projectId}) async =>
      TaskOut.fromJson(
        await _map(
          'POST',
          '/tasks/$taskId/copy',
          body: {'project_id': projectId},
        ),
      );

  // Groups

  Future<List<ProjectGroup>> groups({bool includeInactive = false}) async => [
    for (final j in asMapList(
      await workspace.call(
        'GET',
        '/project-groups${WorkspaceApi.query({'include_inactive': includeInactive ? 'true' : null})}',
      ),
    ))
      ProjectGroup.fromJson(j),
  ];

  Future<ProjectGroup> createGroup(
    String name, {
    required String scope,
  }) async => ProjectGroup.fromJson(
    await _map('POST', '/project-groups', body: {'name': name, 'scope': scope}),
  );

  Future<ProjectGroup> patchGroup(int id, {String? name, bool? active}) async =>
      ProjectGroup.fromJson(
        await _map(
          'PATCH',
          '/project-groups/$id',
          body: {'name': ?name, 'active': ?active},
        ),
      );

  // Optional endpoints (another server agent adds them; a 404 means "not there yet")

  /// Attachments of every task of the project. [type] is `image`, `video` or `document`.
  /// Throws [NotFoundException] when the server has no such endpoint.
  Future<List<ProjectFile>> files(
    String id, {
    String type = '',
    String q = '',
    int limit = 100,
    int offset = 0,
  }) async {
    final params = WorkspaceApi.query({
      'type': type,
      'q': q,
      'limit': limit,
      'offset': offset,
    });
    final data = await workspace.call('GET', '/projects/$id/files$params');
    return [for (final j in asMapList(data)) ProjectFile.fromJson(j)];
  }

  /// Copies the project with its columns. Throws [NotFoundException] on older servers.
  Future<ProjectOut> copyProject(String id, String name) =>
      _project('POST', '/projects/$id/copy', body: {'name': name});
}
