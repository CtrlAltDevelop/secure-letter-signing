import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/tasks/models.dart' show TaskBrief;
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// Advanced search criteria for `GET /letters/search`; empty fields are not sent.
class LetterSearch {
  const LetterSearch({
    this.q = '',
    this.status = '',
    this.label,
    this.number = '',
    this.creator = '',
    this.signer = '',
    this.from,
    this.to,
    this.box = 'all',
  });

  final String q;
  final String status;
  final int? label;
  final String number;
  final String creator;
  final String signer;
  final DateTime? from;
  final DateTime? to;
  final String box;

  /// Number of criteria set (the box does not count).
  int get activeCount => [
    q.isNotEmpty,
    status.isNotEmpty,
    label != null,
    number.isNotEmpty,
    creator.isNotEmpty,
    signer.isNotEmpty,
    from != null,
    to != null,
  ].where((e) => e).length;

  bool get isEmpty => activeCount == 0;

  LetterSearch copyWith({
    String? q,
    String? status,
    int? label,
    bool clearLabel = false,
    String? number,
    String? creator,
    String? signer,
    DateTime? from,
    bool clearFrom = false,
    DateTime? to,
    bool clearTo = false,
    String? box,
  }) => LetterSearch(
    q: q ?? this.q,
    status: status ?? this.status,
    label: clearLabel ? null : (label ?? this.label),
    number: number ?? this.number,
    creator: creator ?? this.creator,
    signer: signer ?? this.signer,
    from: clearFrom ? null : (from ?? this.from),
    to: clearTo ? null : (to ?? this.to),
    box: box ?? this.box,
  );

  static String _day(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)}';
  }

  Map<String, Object?> toQuery({int limit = 100, int offset = 0}) => {
    'q': q,
    'status': status,
    'label': label,
    'number': number,
    'creator': creator,
    'signer': signer,
    'from': from == null ? null : _day(from!),
    'to': to == null ? null : _day(to!),
    'box': box == 'all' ? null : box,
    'limit': limit,
    'offset': offset,
  };
}

/// Letters v2 endpoints: search, archive, referrals, linked tasks, paraphs, secretariat. Errors
/// 403/404/409 are typed (see `workspace_api.dart`).
class LettersV2Api {
  LettersV2Api(this.workspace);

  final WorkspaceApi workspace;

  Future<List<LetterBrief>> search(
    LetterSearch criteria, {
    int limit = 100,
    int offset = 0,
  }) async {
    final q = WorkspaceApi.query(
      criteria.toQuery(limit: limit, offset: offset),
    );
    final data = await workspace.call('GET', '/letters/search$q');
    return [for (final j in asMapList(data)) LetterBrief.fromJson(j)];
  }

  Future<LetterBrief> archive(String id, {required bool archived}) async =>
      LetterBrief.fromJson(
        asMap(
          await workspace.call(
            'POST',
            '/letters/$id/archive',
            body: {'archived': archived},
          ),
        ),
      );

  // Referrals

  Future<List<ReferralInfo>> referrals(String id) async => [
    for (final j in asMapList(
      await workspace.call('GET', '/letters/$id/referrals'),
    ))
      ReferralInfo.fromJson(j),
  ];

  Future<List<ReferralInfo>> refer(
    String id, {
    required List<int> userIds,
    String note = '',
  }) async => [
    for (final j in asMapList(
      await workspace.call(
        'POST',
        '/letters/$id/refer',
        body: {'user_ids': userIds, 'note': note},
      ),
    ))
      ReferralInfo.fromJson(j),
  ];

  /// [status] is `done` or `declined`.
  Future<ReferralInfo> respond(
    int referralId, {
    required String status,
    String note = '',
  }) async => ReferralInfo.fromJson(
    asMap(
      await workspace.call(
        'POST',
        '/referrals/$referralId/respond',
        body: {'status': status, 'note': note},
      ),
    ),
  );

  // Linked tasks

  Future<List<TaskBrief>> linkedTasks(String id) async => [
    for (final j in asMapList(
      await workspace.call('GET', '/letters/$id/tasks'),
    ))
      TaskBrief.fromJson(j),
  ];

  Future<TaskBrief> linkTask(String id, String taskId) async =>
      TaskBrief.fromJson(
        asMap(
          await workspace.call(
            'POST',
            '/letters/$id/tasks',
            body: {'task_id': taskId},
          ),
        ),
      );

  Future<void> unlinkTask(String id, String taskId) =>
      workspace.call('DELETE', '/letters/$id/tasks/$taskId');

  /// Tasks the caller may link: `GET /tasks` (every box, any status).
  Future<List<TaskBrief>> searchTasks(String q) async {
    final params = WorkspaceApi.query({'box': 'all', 'q': q, 'limit': 30});
    final data = await workspace.call('GET', '/tasks$params');
    return [for (final j in asMapList(data)) TaskBrief.fromJson(j)];
  }

  // Paraph

  Future<ParaphInfo> paraphWithPin(String id, String pin) async =>
      ParaphInfo.fromJson(
        asMap(
          await workspace.call(
            'POST',
            '/letters/$id/paraph',
            body: {'pin': pin},
          ),
        ),
      );

  Future<ParaphInfo> paraphWithBiometric(String id) async =>
      ParaphInfo.fromJson(
        asMap(await workspace.call('POST', '/letters/$id/paraph-biometric')),
      );

  // Secretariat

  Future<List<SecretariatEntry>> entries({
    String direction = '',
    String q = '',
    int? year,
    int limit = 100,
    int offset = 0,
  }) async {
    final params = WorkspaceApi.query({
      'direction': direction,
      'q': q,
      'year': year,
      'limit': limit,
      'offset': offset,
    });
    final data = await workspace.call('GET', '/secretariat/entries$params');
    return [for (final j in asMapList(data)) SecretariatEntry.fromJson(j)];
  }

  Future<SecretariatEntry> entry(String id) async => SecretariatEntry.fromJson(
    asMap(await workspace.call('GET', '/secretariat/entries/$id')),
  );

  Future<SecretariatEntry> register({
    required String direction,
    required String title,
    String partyName = '',
    String partyRef = '',
    String? letterId,
    String summary = '',
  }) async => SecretariatEntry.fromJson(
    asMap(
      await workspace.call(
        'POST',
        '/secretariat/entries',
        body: {
          'direction': direction,
          'title': title,
          'party_name': partyName,
          'party_ref': partyRef,
          'letter_id': ?letterId,
          'summary': summary,
        },
      ),
    ),
  );

  Future<SecretariatEntry> patchEntry(
    String id, {
    required String title,
    required String partyName,
    required String partyRef,
    required String summary,
  }) async => SecretariatEntry.fromJson(
    asMap(
      await workspace.call(
        'PATCH',
        '/secretariat/entries/$id',
        body: {
          'title': title,
          'party_name': partyName,
          'party_ref': partyRef,
          'summary': summary,
        },
      ),
    ),
  );
}
