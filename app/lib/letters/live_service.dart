import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/letters/models.dart';

/// Server close code: token invalid or session ended. Never retried.
const sessionEndedCloseCode = 4401;

/// Minimal socket surface so tests can fake it.
abstract interface class LiveChannel {
  Stream<dynamic> get stream;
  Future<void> get ready;
  void send(String text);
  int? get closeCode;
  Future<void> close();
}

class _WsChannel implements LiveChannel {
  _WsChannel(this._ws);
  final WebSocketChannel _ws;
  @override
  Stream<dynamic> get stream => _ws.stream;
  @override
  Future<void> get ready => _ws.ready;
  @override
  void send(String text) => _ws.sink.add(text);
  @override
  int? get closeCode => _ws.closeCode;
  @override
  Future<void> close() => _ws.sink.close();
}

typedef ChannelFactory = LiveChannel Function(Uri uri);

LiveChannel _connect(Uri uri) => _WsChannel(WebSocketChannel.connect(uri));

/// Persists the last seen event id so catch-up survives restarts.
abstract class CursorStore {
  Future<int> read();
  Future<void> write(int id);
}

class MemoryCursorStore implements CursorStore {
  int _id = 0;
  @override
  Future<int> read() async => _id;
  @override
  Future<void> write(int id) async => _id = id;
}

class SecureCursorStore implements CursorStore {
  const SecureCursorStore(this.userId);
  final int userId;
  static const _storage = FlutterSecureStorage();
  String get _key => 'live_cursor_$userId';
  @override
  Future<int> read() async =>
      int.tryParse(await _storage.read(key: _key) ?? '') ?? 0;
  @override
  Future<void> write(int id) => _storage.write(key: _key, value: '$id');
}

/// Live letter events and notifications over `ws(s)://<apiUrl>/ws/?token=...`.
/// On every (re)connect it sends `{"after": cursor}` for catch-up; reconnects with capped backoff.
class LiveService {
  LiveService({
    required this.api,
    required this.cursor,
    ChannelFactory? channelFactory,
    Future<void> Function(Duration)? delay,
    this.minBackoff = const Duration(seconds: 1),
    this.maxBackoff = const Duration(seconds: 30),
  }) : _factory = channelFactory ?? _connect,
       _delay = delay ?? Future<void>.delayed;

  final ApiClient api;
  final CursorStore cursor;
  final Duration minBackoff;
  final Duration maxBackoff;
  final ChannelFactory _factory;
  final Future<void> Function(Duration) _delay;
  final _events = StreamController<LiveEvent>.broadcast();
  final _connected = StreamController<bool>.broadcast();
  bool _running = false;
  bool _ended = false;
  LiveChannel? _channel;

  Stream<LiveEvent> get events => _events.stream;
  Stream<bool> get connection => _connected.stream;
  bool get sessionEnded => _ended;

  /// http(s)://host -> ws(s)://host/ws/?token=...
  static Uri socketUri(String baseUrl, String token) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '${base.path.replaceAll(RegExp(r'/+$'), '')}/ws/',
      queryParameters: {'token': token},
    );
  }

  void start() {
    if (_running) return;
    _running = true;
    _ended = false;
    unawaited(_loop());
  }

  Future<void> stop() async {
    _running = false;
    await _channel?.close();
  }

  Future<void> _loop() async {
    var backoff = minBackoff;
    while (_running) {
      final outcome = await _session();
      if (!_running || outcome == _Outcome.ended) break;
      if (outcome == _Outcome.hadTraffic) backoff = minBackoff;
      await _delay(backoff);
      backoff = backoff * 2 > maxBackoff ? maxBackoff : backoff * 2;
    }
    _running = false;
  }

  Future<_Outcome> _session() async {
    try {
      await api.call('GET', '/me'); // refreshes an expired access token first
    } on ApiException catch (e) {
      if (e.status == 401) return _end();
      return _Outcome.failed;
    } on Object {
      return _Outcome.failed; // offline: retry with backoff
    }
    final token = api.accessToken;
    if (token == null) return _end();
    final channel = _factory(socketUri(api.baseUrl, token));
    _channel = channel;
    var traffic = false;
    try {
      await channel.ready;
      _connected.add(true);
      channel.send(jsonEncode({'after': await cursor.read()}));
      await for (final raw in channel.stream) {
        traffic = true;
        await _handle(raw);
      }
    } on Object {
      // dropped or never connected: fall through to the close-code check and a retry
    }
    _connected.add(false);
    if (channel.closeCode == sessionEndedCloseCode) return _end();
    return traffic ? _Outcome.hadTraffic : _Outcome.failed;
  }

  _Outcome _end() {
    _ended = true;
    return _Outcome.ended;
  }

  Future<void> _handle(Object? raw) async {
    final Object? data;
    try {
      data = jsonDecode(raw as String);
    } on Object {
      return; // not ours
    }
    if (data is! Map) return;
    final event = LiveEvent(Map<String, dynamic>.from(data));
    final id = event.eventId;
    if (id != null && id > await cursor.read()) await cursor.write(id);
    _events.add(event);
  }

  Future<void> dispose() async {
    await stop();
    await _events.close();
    await _connected.close();
  }
}

enum _Outcome { failed, hadTraffic, ended }
