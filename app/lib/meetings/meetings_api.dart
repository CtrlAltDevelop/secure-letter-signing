import 'package:letter_signing/letters/models.dart' show SessionInfo;
import 'package:letter_signing/meetings/models.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// Filters of `GET /meetings`; empty values are not sent.
class MeetingFilter {
  const MeetingFilter({
    this.status = '',
    this.kind = '',
    this.mine = false,
    this.q = '',
    this.from,
    this.to,
  });

  final String status;
  final String kind;
  final bool mine;
  final String q;
  final DateTime? from;
  final DateTime? to;

  int get activeCount => [
    status.isNotEmpty,
    kind.isNotEmpty,
    mine,
    q.isNotEmpty,
    from != null,
    to != null,
  ].where((e) => e).length;

  MeetingFilter copyWith({
    String? status,
    String? kind,
    bool? mine,
    String? q,
    DateTime? from,
    bool clearFrom = false,
    DateTime? to,
    bool clearTo = false,
  }) => MeetingFilter(
    status: status ?? this.status,
    kind: kind ?? this.kind,
    mine: mine ?? this.mine,
    q: q ?? this.q,
    from: clearFrom ? null : (from ?? this.from),
    to: clearTo ? null : (to ?? this.to),
  );

  /// Start of the chosen day in local time, as UTC.
  static String _start(DateTime d) =>
      DateTime(d.year, d.month, d.day).toUtc().toIso8601String();

  /// End of the chosen day in local time, as UTC.
  static String _end(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59).toUtc().toIso8601String();

  Map<String, Object?> toQuery({int limit = 50, int offset = 0}) => {
    'status': status,
    'kind': kind,
    'mine': mine ? 'true' : null,
    'q': q,
    'from': from == null ? null : _start(from!),
    'to': to == null ? null : _end(to!),
    'limit': limit,
    'offset': offset,
  };
}

/// Result of `POST /meetings/{id}/sms`.
class SmsResult {
  const SmsResult({required this.sent, required this.withoutPhone});
  final int sent;
  final int withoutPhone;
}

/// Typed access to `/meetings` and `/meeting-templates`. Errors 403/404/409 are typed
/// exceptions (see `workspace_api.dart`); the subject-level calls live on [workspace].
class MeetingsApi {
  MeetingsApi(this.workspace);

  final WorkspaceApi workspace;

  Future<Map<String, dynamic>> _map(
    String method,
    String path, {
    Object? body,
  }) async => asMap(await workspace.call(method, path, body: body));

  Future<MeetingOut> _meeting(
    String method,
    String path, {
    Object? body,
  }) async => MeetingOut.fromJson(await _map(method, path, body: body));

  Future<List<MeetingBrief>> list(
    MeetingFilter filter, {
    int limit = 50,
    int offset = 0,
  }) async {
    final q = WorkspaceApi.query(filter.toQuery(limit: limit, offset: offset));
    final data = await workspace.call('GET', '/meetings$q');
    return [for (final j in asMapList(data)) MeetingBrief.fromJson(j)];
  }

  Future<MeetingOut> get(String id) => _meeting('GET', '/meetings/$id');

  Future<MeetingOut> create(MeetingDraft draft, {required bool schedule}) =>
      _meeting(
        'POST',
        '/meetings',
        body: draft.toCreateJson(schedule: schedule),
      );

  Future<MeetingOut> patch(String id, Map<String, dynamic> fields) =>
      _meeting('PATCH', '/meetings/$id', body: fields);

  Future<MeetingOut> setAttendees(String id, List<AttendeeDraft> attendees) =>
      _meeting(
        'PUT',
        '/meetings/$id/attendees',
        body: [for (final a in attendees) a.toJson()],
      );

  Future<MeetingOut> markAttendance(
    String id, {
    required int attendeeId,
    required String attendance,
  }) => _meeting(
    'POST',
    '/meetings/$id/attendance',
    body: {'attendee_id': attendeeId, 'attendance': attendance},
  );

  Future<Resolution> addResolution(
    String id, {
    required String text,
    DateTime? dueAt,
    List<int> ownerIds = const [],
  }) async => Resolution.fromJson(
    await _map(
      'POST',
      '/meetings/$id/resolutions',
      body: {
        'text': text,
        'due_at': dueAt?.toUtc().toIso8601String(),
        'owner_ids': ownerIds,
      },
    ),
  );

  Future<Resolution> editResolution(
    String id,
    int resolutionId, {
    String? text,
    DateTime? dueAt,
    List<int>? ownerIds,
    String? status,
    bool? active,
  }) async => Resolution.fromJson(
    await _map(
      'PATCH',
      '/meetings/$id/resolutions/$resolutionId',
      body: {
        'text': ?text,
        'due_at': ?dueAt?.toUtc().toIso8601String(),
        'owner_ids': ?ownerIds,
        'status': ?status,
        'active': ?active,
      },
    ),
  );

  /// [action] is `schedule`, `hold`, `close`, `reopen` or `cancel`.
  Future<MeetingOut> transition(String id, String action) =>
      _meeting('POST', '/meetings/$id/$action');

  Future<MeetingOut> signWithPin(
    String id, {
    required String decision,
    required String note,
    required String pin,
  }) => _meeting(
    'POST',
    '/meetings/$id/sign',
    body: {'decision': decision, 'note': note, 'pin': pin},
  );

  Future<MeetingOut> signWithBiometric(
    String id, {
    required String decision,
    required String note,
  }) => _meeting(
    'POST',
    '/meetings/$id/sign-biometric',
    body: {'decision': decision, 'note': note},
  );

  /// Number of reminders created.
  Future<int> remind(String id, int offsetMinutes) async {
    final data = await _map(
      'POST',
      '/meetings/$id/remind',
      body: {'offset_minutes': offsetMinutes},
    );
    return asInt(data['reminders']) ?? 0;
  }

  Future<SmsResult> sendSms(String id, String text) async {
    final data = await _map('POST', '/meetings/$id/sms', body: {'text': text});
    return SmsResult(
      sent: asInt(data['sent']) ?? 0,
      withoutPhone: asInt(data['without_phone']) ?? 0,
    );
  }

  /// This user's signed-in devices (for the biometric flag of the current session).
  Future<List<SessionInfo>> sessions() async => [
    for (final j in asMapList(await workspace.call('GET', '/me/sessions')))
      SessionInfo.fromJson(j),
  ];

  // Templates

  Future<List<MeetingTemplate>> templates({
    bool includeInactive = false,
  }) async {
    final q = includeInactive ? '?include_inactive=true' : '';
    final data = await workspace.call('GET', '/meeting-templates$q');
    return [for (final j in asMapList(data)) MeetingTemplate.fromJson(j)];
  }

  Future<MeetingTemplate> createTemplate({
    required String name,
    required String scope,
    required Map<String, dynamic> data,
  }) async => MeetingTemplate.fromJson(
    await _map(
      'POST',
      '/meeting-templates',
      body: {'name': name, 'scope': scope, 'data': data},
    ),
  );

  Future<MeetingTemplate> patchTemplate(
    int id, {
    String? name,
    Map<String, dynamic>? data,
    bool? active,
  }) async => MeetingTemplate.fromJson(
    await _map(
      'PATCH',
      '/meeting-templates/$id',
      body: {'name': ?name, 'data': ?data, 'active': ?active},
    ),
  );
}
