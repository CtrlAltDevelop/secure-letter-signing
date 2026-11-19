import 'package:http/http.dart' as http;

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/tasks/models.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

export 'package:letter_signing/workspace/workspace_api.dart'
    show ConflictException, ForbiddenException, NotFoundException;

/// Typed access to the `/tasks` endpoints. The subject-level calls (comments, files, history,
/// seen-by, labels, directory) live on [workspace]. Errors 403/404/409 are typed exceptions.
class TasksApi {
  TasksApi(ApiClient client, {http.Client? httpClient})
    : workspace = WorkspaceApi(client, httpClient: httpClient);

  final WorkspaceApi workspace;

  Future<Map<String, dynamic>> _map(
    String method,
    String path, {
    Object? body,
  }) async => asMap(await workspace.call(method, path, body: body));

  Future<TaskOut> _task(String method, String path, {Object? body}) async =>
      TaskOut.fromJson(await _map(method, path, body: body));

  /// [box] is `inbox`, `followup` or `all`; [status] an empty string for every status.
  Future<List<TaskBrief>> list({
    String box = 'all',
    String status = '',
    String q = '',
    int? label,
    DateTime? dueBefore,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = WorkspaceApi.query({
      'box': box,
      'status': status,
      'q': q,
      'label': label,
      'due_before': dueBefore?.toUtc().toIso8601String(),
      'limit': limit,
      'offset': offset,
    });
    final data = await workspace.call('GET', '/tasks$params');
    return [for (final j in asMapList(data)) TaskBrief.fromJson(j)];
  }

  Future<TaskOut> get(String id) => _task('GET', '/tasks/$id');

  Future<TaskOut> create(TaskDraft draft) =>
      _task('POST', '/tasks', body: draft.toCreateJson());

  Future<void> markSeen(String id) => workspace.call('POST', '/tasks/$id/seen');

  /// `PATCH` with the loaded [version]; a stale one throws [ConflictException].
  Future<TaskOut> patch(
    String id,
    Map<String, dynamic> fields, {
    required int version,
  }) => _task('PATCH', '/tasks/$id', body: {'version': version, ...fields});

  Future<TaskOut> setPeople(
    String id, {
    required List<int> ownerIds,
    required List<int> approverIds,
    required List<int> followerIds,
    required int version,
  }) => _task(
    'PUT',
    '/tasks/$id/people',
    body: {
      'owner_ids': ownerIds,
      'approver_ids': approverIds,
      'follower_ids': followerIds,
      'version': version,
    },
  );

  Future<TaskOut> addChecklistItem(String id, String text) =>
      _task('POST', '/tasks/$id/checklist', body: {'text': text});

  Future<TaskOut> patchChecklistItem(
    String id,
    int itemId, {
    String? text,
    bool? done,
    bool? active,
  }) => _task(
    'PATCH',
    '/tasks/$id/checklist/$itemId',
    body: {'text': ?text, 'done': ?done, 'active': ?active},
  );

  /// The brief names the body key `ids`, the server schema `item_ids`: both are sent.
  Future<TaskOut> reorderChecklist(String id, List<int> itemIds) => _task(
    'PUT',
    '/tasks/$id/checklist/order',
    body: {'ids': itemIds, 'item_ids': itemIds},
  );

  Future<TaskOut> complete(String id, {String note = ''}) => _task(
    'POST',
    '/tasks/$id/complete',
    body: {if (note.isNotEmpty) 'note': note},
  );

  /// [decision] is `approve` or `reject`; a rejection needs a [note].
  Future<TaskOut> decide(String id, String decision, {String note = ''}) =>
      _task(
        'POST',
        '/tasks/$id/decision',
        body: {'decision': decision, 'note': note},
      );

  Future<TaskOut> reopen(String id) => _task('POST', '/tasks/$id/reopen');

  Future<TaskOut> cancel(String id) => _task('POST', '/tasks/$id/cancel');
}
