import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/letters/letterhead.dart';
import 'package:letter_signing/letters/models.dart';

/// Typed access to the letters endpoints, built on [ApiClient] (auth + refresh).
/// Attachments are binary/multipart, so they use [http] directly with the client's current token.
class LettersApi {
  LettersApi(this.client, {http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final ApiClient client;
  final http.Client _http;

  /// The HTTP client used for binary calls, shared with the workspace API of the same env.
  http.Client get httpClient => _http;

  Future<List<T>> _list<T>(
    String path,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final data = await client.call('GET', path) as List;
    return [for (final e in data) parse(Map<String, dynamic>.from(e as Map))];
  }

  Future<Map<String, dynamic>> _map(
    String method,
    String path, {
    Object? body,
  }) async => Map<String, dynamic>.from(
    await client.call(method, path, body: body) as Map,
  );

  /// Company letterhead (manager-configured, readable by every user).
  Future<Letterhead> letterhead() async =>
      Letterhead.fromJson(await _map('GET', '/me/letterhead'));

  String _query(Map<String, Object?> params) {
    final q = {
      for (final e in params.entries)
        if (e.value != null) e.key: '${e.value}',
    };
    return q.isEmpty ? '' : '?${Uri(queryParameters: q).query}';
  }

  /// [box] is `all` (default), `inbox`, `outbox` or `archive`.
  Future<List<LetterBrief>> list({
    String q = '',
    String box = 'all',
    int limit = 200,
    int offset = 0,
  }) => _list(
    '/letters${_query({'q': q.isEmpty ? null : q, 'box': box == 'all' ? null : box, 'limit': limit, 'offset': offset})}',
    LetterBrief.fromJson,
  );

  /// Replaces the customer-file links of a letter (creator or secretariat; others get 403).
  Future<List<String>> setCustomers(String id, List<String> refs) async {
    final data = await _map(
      'PUT',
      '/letters/$id/customers',
      body: {'customer_refs': refs},
    );
    return [for (final r in (data['customer_refs'] as List? ?? const [])) '$r'];
  }

  Future<LetterDetail> detail(String id) async =>
      LetterDetail.fromJson(await _map('GET', '/letters/$id'));

  Future<LetterBrief> createDraft(DraftPayload draft) async =>
      LetterBrief.fromJson(
        await _map('POST', '/letters', body: draft.toJson()),
      );

  Future<LetterBrief> updateDraft(String id, DraftPayload draft) async =>
      LetterBrief.fromJson(
        await _map('PUT', '/letters/$id', body: draft.toJson()),
      );

  Future<LetterBrief> send(String id) async =>
      LetterBrief.fromJson(await _map('POST', '/letters/$id/send'));

  Future<LetterBrief> cancel(String id) async =>
      LetterBrief.fromJson(await _map('POST', '/letters/$id/cancel'));

  Future<void> markOpened(String id) =>
      client.call('POST', '/letters/$id/opened');

  /// Signs with the 6-digit signing PIN.
  Future<LetterBrief> sign(
    String id, {
    required String decision,
    required String note,
    required String pin,
  }) async => LetterBrief.fromJson(
    await _map(
      'POST',
      '/letters/$id/sign',
      body: {'decision': decision, 'note': note, 'pin': pin},
    ),
  );

  /// Signs on a biometric session after the app confirmed fingerprint/face locally.
  Future<LetterBrief> signBiometric(
    String id, {
    required String decision,
    required String note,
  }) async => LetterBrief.fromJson(
    await _map(
      'POST',
      '/letters/$id/sign-biometric',
      body: {'decision': decision, 'note': note},
    ),
  );

  /// Asks another biometric session of this user to approve the signature.
  Future<SignRequest> createSignRequest(
    String id, {
    required String decision,
    required String note,
    required String approverSessionId,
  }) async => SignRequest.fromJson(
    await _map(
      'POST',
      '/letters/$id/sign-requests',
      body: {
        'decision': decision,
        'note': note,
        'approver_session_id': approverSessionId,
      },
    ),
  );

  Future<List<SignRequest>> incomingSignRequests() =>
      _list('/sign-requests/incoming', SignRequest.fromJson);

  Future<SignRequest> signRequest(String id) async =>
      SignRequest.fromJson(await _map('GET', '/sign-requests/$id'));

  Future<SignRequest> approveSignRequest(String id) async =>
      SignRequest.fromJson(await _map('POST', '/sign-requests/$id/approve'));

  Future<SignRequest> declineSignRequest(String id) async =>
      SignRequest.fromJson(await _map('POST', '/sign-requests/$id/decline'));

  Future<SignRequest> cancelSignRequest(String id) async =>
      SignRequest.fromJson(await _map('POST', '/sign-requests/$id/cancel'));

  /// This user's signed-in devices (with their `biometric` flag).
  Future<List<SessionInfo>> sessions() =>
      _list('/me/sessions', SessionInfo.fromJson);

  /// Published Ed25519 company seal key: `{alg, public_key, fingerprint}`.
  Future<Map<String, dynamic>> sealKey() => _map('GET', '/letters/seal-key');

  Future<List<LiveEvent>> eventsAfter(int after) =>
      _list('/letters/events?after=$after', LiveEvent.new);

  Future<Map<String, dynamic>> certificate(String id) =>
      _map('GET', '/letters/$id/certificate');

  /// Active colleagues for picking signers/viewers.
  /// Assumed server shape: `GET /letters/directory` -> `[{id, email, full_name, permissions[]}]`.
  Future<List<DirectoryUser>> directory() =>
      _list('/letters/directory', DirectoryUser.fromJson);

  // Manager
  Future<List<AdminLetter>> adminList({int limit = 200, int offset = 0}) =>
      _list(
        '/letters/admin${_query({'limit': limit, 'offset': offset})}',
        AdminLetter.fromJson,
      );

  Future<LetterBrief> setUnlisted(String id, {required bool unlisted}) async =>
      LetterBrief.fromJson(
        await _map('POST', '/letters/$id/unlist', body: {'unlisted': unlisted}),
      );

  // Notifications
  Future<List<AppNotification>> notifications({int after = 0}) =>
      _list('/me/notifications?after=$after', AppNotification.fromJson);

  Future<void> markNotificationsRead() =>
      client.call('POST', '/me/notifications/read');

  // Attachments (plain bytes; the server encrypts them at rest)
  Future<AttachmentInfo> uploadAttachment(
    String letterId, {
    required Uint8List bytes,
    required String contentType,
    required String label,
  }) async {
    final res = await _withAuth((token) async {
      final req =
          http.MultipartRequest(
              'POST',
              Uri.parse('${client.baseUrl}/api/letters/$letterId/attachments'),
            )
            ..fields.addAll({'content_type': contentType, 'label': label})
            ..files.add(
              http.MultipartFile.fromBytes('file', bytes, filename: 'file'),
            )
            ..headers['Authorization'] = 'Bearer $token';
      return http.Response.fromStream(await _http.send(req));
    });
    return AttachmentInfo.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<Uint8List> downloadAttachment(
    String letterId,
    String attachmentId,
  ) async {
    final res = await _withAuth(
      (token) => _http.get(
        Uri.parse(
          '${client.baseUrl}/api/letters/$letterId/attachments/$attachmentId',
        ),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    if (res.statusCode != 200) _decode(res);
    return res.bodyBytes;
  }

  /// Runs [send] with the current token; on a 401 forces a refresh (via an authenticated call) and retries once.
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
    throw ApiException(res.statusCode, detail);
  }
}
