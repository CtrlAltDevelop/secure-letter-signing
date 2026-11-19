import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/workspace/models.dart';

/// 403: the server refused this action for this user.
class ForbiddenException extends ApiException {
  const ForbiddenException(String message) : super(403, message);
}

/// 404: the item does not exist or is invisible to this user.
class NotFoundException extends ApiException {
  const NotFoundException(String message) : super(404, message);
}

/// 409: the item changed since it was loaded (stale `version`) or the action conflicts.
class ConflictException extends ApiException {
  const ConflictException(String message) : super(409, message);
}

/// Turns the status codes the UI reacts to into typed errors; others pass through.
ApiException typedError(ApiException e) => switch (e.status) {
  403 => ForbiddenException(e.message),
  404 => NotFoundException(e.message),
  409 => ConflictException(e.message),
  _ => e,
};

/// Calls shared by every module that sits on `Subject`: comments, files, history, seen-by,
/// labels and the people directory. Errors 403/404/409 are thrown as typed exceptions.
class WorkspaceApi {
  WorkspaceApi(this.client, {http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final ApiClient client;
  final http.Client _http;

  /// JSON call with typed errors.
  Future<dynamic> call(String method, String path, {Object? body}) async {
    try {
      return await client.call(method, path, body: body);
    } on ApiException catch (e) {
      throw typedError(e);
    }
  }

  /// `?a=1&b=2` from the non-null entries, or an empty string.
  static String query(Map<String, Object?> params) {
    final q = {
      for (final e in params.entries)
        if (e.value != null && '${e.value}'.isNotEmpty) e.key: '${e.value}',
    };
    return q.isEmpty ? '' : '?${Uri(queryParameters: q).query}';
  }

  /// Active colleagues for pickers. Assumed: `[{id, email, full_name, ...}]`.
  Future<List<UserRef>> directory() async => [
    for (final j in asMapList(await call('GET', '/letters/directory')))
      UserRef.fromJson(j),
  ];

  Future<List<LabelInfo>> labels() async => [
    for (final j in asMapList(await call('GET', '/labels')))
      LabelInfo.fromJson(j),
  ];

  /// Labels including deactivated ones, for the management screen.
  Future<List<LabelInfo>> allLabels() async => [
    for (final j in asMapList(
      await call('GET', '/labels?include_inactive=true'),
    ))
      LabelInfo.fromJson(j),
  ];

  /// [scope] is `org` (manager only) or `personal`; a duplicate name is a [ConflictException].
  Future<LabelInfo> createLabel({
    required String name,
    required int color,
    required String scope,
  }) async => LabelInfo.fromJson(
    asMap(
      await call(
        'POST',
        '/labels',
        body: {'name': name, 'color': color, 'scope': scope},
      ),
    ),
  );

  Future<LabelInfo> patchLabel(
    int id, {
    String? name,
    int? color,
    bool? active,
  }) async => LabelInfo.fromJson(
    asMap(
      await call(
        'PATCH',
        '/labels/$id',
        body: {'name': ?name, 'color': ?color, 'active': ?active},
      ),
    ),
  );

  // Reminders

  Future<List<ReminderInfo>> reminders(String subjectId) async => [
    for (final j in asMapList(
      await call('GET', '/subjects/$subjectId/reminders'),
    ))
      ReminderInfo.fromJson(j),
  ];

  Future<ReminderInfo> addReminder(
    String subjectId, {
    required DateTime at,
    ReminderRule? rule,
  }) async => ReminderInfo.fromJson(
    asMap(
      await call(
        'POST',
        '/subjects/$subjectId/reminders',
        body: {'at': at.toUtc().toIso8601String(), 'rule': rule?.toJson()},
      ),
    ),
  );

  Future<void> deactivateReminder(int id) => call('DELETE', '/reminders/$id');

  /// Replaces the labels of a subject.
  Future<List<int>> setLabels(String subjectId, List<int> labelIds) async {
    final data = await call(
      'PUT',
      '/subjects/$subjectId/labels',
      body: {'label_ids': labelIds},
    );
    return asIntList(asMap(data)['label_ids']);
  }

  // Comments

  Future<List<CommentInfo>> comments(String subjectId) async =>
      CommentInfo.parseAll(await call('GET', '/subjects/$subjectId/comments'));

  Future<CommentInfo> addComment(
    String subjectId, {
    required String text,
    int? parentId,
    String kind = CommentInfo.commentKind,
    int? progress,
  }) async => CommentInfo.fromJson(
    asMap(
      await call(
        'POST',
        '/subjects/$subjectId/comments',
        body: {
          'body': {'text': text},
          'parent_id': ?parentId,
          'kind': kind,
          'progress': ?progress,
        },
      ),
    ),
  );

  Future<CommentInfo> editComment(int id, String text) async =>
      CommentInfo.fromJson(
        asMap(
          await call(
            'PATCH',
            '/comments/$id',
            body: {
              'body': {'text': text},
            },
          ),
        ),
      );

  Future<void> deactivateComment(int id) => call('DELETE', '/comments/$id');

  // Files

  Future<List<FileInfo>> files(String subjectId) async => [
    for (final j in asMapList(await call('GET', '/subjects/$subjectId/files')))
      FileInfo.fromJson(j),
  ];

  Future<FileInfo> uploadFile(
    String subjectId, {
    required String name,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final res = await _withAuth((token) async {
      final req =
          http.MultipartRequest(
              'POST',
              Uri.parse('${client.baseUrl}/api/subjects/$subjectId/files'),
            )
            ..fields.addAll({'content_type': contentType, 'name': name})
            ..files.add(
              http.MultipartFile.fromBytes('file', bytes, filename: name),
            )
            ..headers['Authorization'] = 'Bearer $token';
      return http.Response.fromStream(await _http.send(req));
    });
    return FileInfo.fromJson(asMap(_decode(res)));
  }

  /// Multipart `POST` of one file under the form field `file` plus plain [fields]; returns the
  /// decoded JSON answer (errors are typed like [call]).
  Future<Object?> postFile(
    String path, {
    required String name,
    required Uint8List bytes,
    Map<String, String> fields = const {},
  }) async {
    final res = await _withAuth((token) async {
      final req =
          http.MultipartRequest('POST', Uri.parse('${client.baseUrl}/api$path'))
            ..fields.addAll(fields)
            ..files.add(
              http.MultipartFile.fromBytes('file', bytes, filename: name),
            )
            ..headers['Authorization'] = 'Bearer $token';
      return http.Response.fromStream(await _http.send(req));
    });
    return _decode(res);
  }

  Future<Uint8List> downloadFile(String fileId) async {
    final res = await _withAuth(
      (token) => _http.get(
        Uri.parse('${client.baseUrl}/api/files/$fileId'),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    if (res.statusCode != 200) _decode(res);
    return res.bodyBytes;
  }

  /// Raw bytes of an authenticated `GET` (for example `/me/background`).
  Future<Uint8List> getBytes(String path) async {
    final res = await _withAuth(
      (token) => _http.get(
        Uri.parse('${client.baseUrl}/api$path'),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    if (res.statusCode != 200) _decode(res);
    return res.bodyBytes;
  }

  Future<void> deactivateFile(String fileId) =>
      call('DELETE', '/files/$fileId');

  // History and seen-by

  Future<List<HistoryEntry>> history(String subjectId) async => [
    for (final j in asMapList(
      await call('GET', '/subjects/$subjectId/history'),
    ))
      HistoryEntry.fromJson(j),
  ];

  Future<List<SeenEntry>> seenBy(String subjectId) async => [
    for (final j in asMapList(await call('GET', '/subjects/$subjectId/seen')))
      SeenEntry.fromJson(j),
  ];

  Future<void> markSeen(String subjectId) =>
      call('POST', '/subjects/$subjectId/seen');

  /// Runs [send] with the current token; on a 401 refreshes through an authenticated call and
  /// retries once.
  Future<http.Response> _withAuth(
    Future<http.Response> Function(String token) send,
  ) async {
    var res = await send(client.accessToken ?? '');
    if (res.statusCode == 401) {
      await client.call('GET', '/me');
      res = await send(client.accessToken ?? '');
    }
    return res;
  }

  static Object? _decode(http.Response res) {
    final text = utf8.decode(res.bodyBytes);
    Object? body;
    try {
      body = text.isEmpty ? null : jsonDecode(text);
    } on FormatException {
      body = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final detail = body is Map && body['detail'] is String
        ? body['detail'] as String
        : 'Request failed (${res.statusCode})';
    throw typedError(ApiException(res.statusCode, detail));
  }
}
