import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

/// Where the refresh token lives between launches.
abstract class TokenStore {
  Future<String?> readRefresh();
  Future<void> writeRefresh(String token);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  const SecureTokenStore();
  static const _key = 'refresh_token';
  static const _storage = FlutterSecureStorage();
  @override
  Future<String?> readRefresh() => _storage.read(key: _key);
  @override
  Future<void> writeRefresh(String token) =>
      _storage.write(key: _key, value: token);
  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class MemoryTokenStore implements TokenStore {
  String? _token;
  @override
  Future<String?> readRefresh() async => _token;
  @override
  Future<void> writeRefresh(String token) async => _token = token;
  @override
  Future<void> clear() async => _token = null;
}

/// JSON client for the server. Sends the access token, and on a 401 refreshes once and retries.
/// The access token is kept in memory only; the rotating refresh token goes to [TokenStore].
class ApiClient {
  ApiClient({required this.baseUrl, required this.store, http.Client? client})
    : _http = client ?? http.Client();

  final String baseUrl;
  final TokenStore store;
  final http.Client _http;
  String? _access;

  /// Current access token (memory only). For the WebSocket handshake and binary uploads.
  String? get accessToken => _access;
  Future<bool>? _refreshing;

  /// Called when the session can no longer be refreshed (revoked, expired, user deactivated).
  void Function()? onSessionLost;

  void setSession({required String access, required String refresh}) {
    _access = access;
    unawaited(store.writeRefresh(refresh));
  }

  Future<void> clearSession() async {
    _access = null;
    await store.clear();
  }

  Future<dynamic> call(
    String method,
    String path, {
    Object? body,
    bool auth = true,
  }) async {
    var res = await _send(method, path, body, auth);
    if (res.statusCode == 401 && auth && await _refreshOnce()) {
      res = await _send(method, path, body, auth);
    }
    final text = utf8.decode(res.bodyBytes);
    final decoded = text.isEmpty ? null : jsonDecode(text);
    if (res.statusCode >= 200 && res.statusCode < 300) return decoded;
    throw ApiException(
      res.statusCode,
      _detail(decoded) ?? 'Request failed (${res.statusCode})',
    );
  }

  Future<http.Response> _send(
    String method,
    String path,
    Object? body,
    bool auth,
  ) {
    final request = http.Request(method, Uri.parse('$baseUrl/api$path'))
      ..headers['Content-Type'] = 'application/json';
    if (auth && _access != null)
      request.headers['Authorization'] = 'Bearer $_access';
    if (body != null) request.body = jsonEncode(body);
    return _http
        .send(request)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 20));
  }

  /// One refresh at a time: the server rotates the token, so a parallel second use would look like theft.
  Future<bool> _refreshOnce() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<bool> _refresh() async {
    final refresh = await store.readRefresh();
    if (refresh == null) return false;
    final res = await _send('POST', '/auth/refresh', {
      'refresh': refresh,
    }, false);
    if (res.statusCode != 200) {
      if (res.statusCode == 401) {
        await clearSession();
        onSessionLost?.call();
      }
      return false;
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    _access = data['access'] as String;
    await store.writeRefresh(data['refresh'] as String);
    return true;
  }

  /// Restores a session from the stored refresh token (app start). Returns false if there is none.
  Future<bool> restore() async =>
      (await store.readRefresh()) != null && await _refreshOnce();

  static String? _detail(Object? body) {
    if (body is Map && body['detail'] is String)
      return body['detail'] as String;
    if (body is Map && body['detail'] is List) {
      return (body['detail'] as List)
          .map((e) => e is Map ? e['msg'] : e)
          .join(', ');
    }
    return null;
  }
}
