import 'dart:typed_data';

import 'package:letter_signing/crm/models.dart';
import 'package:letter_signing/letters/models.dart' show LetterBrief;
import 'package:letter_signing/meetings/models.dart' show MeetingBrief;
import 'package:letter_signing/tasks/models.dart' show TaskBrief;
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// Typed access to `/customers`. The subject-level calls (comments, files, labels) live on
/// [workspace]. Errors 403/404/409 are typed exceptions.
class CrmApi {
  CrmApi(this.workspace);

  final WorkspaceApi workspace;

  Future<Customer> _customer(String method, String path, {Object? body}) async =>
      Customer.fromJson(asMap(await workspace.call(method, path, body: body)));

  Future<List<Customer>> list(
    CustomerFilter filter, {
    int limit = 50,
    int offset = 0,
  }) async {
    final q = WorkspaceApi.query(filter.toQuery(limit: limit, offset: offset));
    final data = await workspace.call('GET', '/customers$q');
    return [for (final j in asMapList(data)) Customer.fromJson(j)];
  }

  Future<Customer> get(String id) => _customer('GET', '/customers/$id');

  /// A 409 is [ConflictException] (the customer limit of the plan).
  Future<Customer> create(CustomerDraft draft, {List<CustomerMember>? members}) =>
      _customer(
        'POST',
        '/customers',
        body: {
          ...draft.toCreateJson(),
          if (members != null) 'members': [for (final m in members) m.toJson()],
        },
      );

  Future<Customer> patch(String id, Map<String, dynamic> fields) =>
      _customer('PATCH', '/customers/$id', body: fields);

  Future<Customer> setMembers(String id, List<CustomerMember> members) =>
      _customer(
        'PUT',
        '/customers/$id/members',
        body: [for (final m in members) m.toJson()],
      );

  Future<List<HistoryEntry>> history(String id) async => [
    for (final j in asMapList(await workspace.call('GET', '/customers/$id/history')))
      HistoryEntry.fromJson(j),
  ];

  Future<List<TimelineEvent>> events(
    String id, {
    String kind = '',
    int limit = 50,
    int offset = 0,
  }) async {
    final q = WorkspaceApi.query({
      'kind': kind,
      'limit': limit,
      'offset': offset,
    });
    final data = await workspace.call('GET', '/customers/$id/events$q');
    return [for (final j in asMapList(data)) TimelineEvent.fromJson(j)];
  }

  Future<TimelineEvent> addEvent(
    String id, {
    required String summary,
    String kind = EventKind.note,
  }) async => TimelineEvent.fromJson(
    asMap(
      await workspace.call(
        'POST',
        '/customers/$id/events',
        body: {'kind': kind, 'summary': summary},
      ),
    ),
  );

  Future<List<CallReport>> calls(String id) async => [
    for (final j in asMapList(await workspace.call('GET', '/customers/$id/calls')))
      CallReport.fromJson(j),
  ];

  Future<CallReport> addCall(
    String id, {
    required String direction,
    String contactName = '',
    String summary = '',
    int durationSeconds = 0,
  }) async => CallReport.fromJson(
    asMap(
      await workspace.call(
        'POST',
        '/customers/$id/calls',
        body: {
          'direction': direction,
          'contact_name': contactName,
          'summary': summary,
          'duration_s': durationSeconds,
        },
      ),
    ),
  );

  /// Creates a follow-up task from a call report (needs `task.create`).
  Future<TaskBrief> callToTask(
    String id,
    int callId, {
    String? title,
    List<int> ownerIds = const [],
    DateTime? dueAt,
  }) async => TaskBrief.fromJson(
    asMap(
      await workspace.call(
        'POST',
        '/customers/$id/calls/$callId/to-task',
        body: {
          if (title != null && title.isNotEmpty) 'title': title,
          'owner_ids': ownerIds,
          'due_at': dueAt?.toUtc().toIso8601String(),
        },
      ),
    ),
  );

  Future<List<TaskBrief>> tasks(String id) async => [
    for (final j in asMapList(await workspace.call('GET', '/customers/$id/tasks')))
      TaskBrief.fromJson(j),
  ];

  Future<List<MeetingBrief>> meetings(String id) async => [
    for (final j in asMapList(
      await workspace.call('GET', '/customers/$id/meetings'),
    ))
      MeetingBrief.fromJson(j),
  ];

  Future<List<LetterBrief>> letters(String id) async => [
    for (final j in asMapList(await workspace.call('GET', '/customers/$id/letters')))
      LetterBrief.fromJson(j),
  ];

  /// [format] is `csv` or `xlsx`.
  Future<ImportResult> importFile({
    required String format,
    required String name,
    required Uint8List bytes,
  }) async => ImportResult.fromJson(
    asMap(
      await workspace.postFile(
        '/customers/import',
        name: name,
        bytes: bytes,
        fields: {'format': format},
      ),
    ),
  );
}
