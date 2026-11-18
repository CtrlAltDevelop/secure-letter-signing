import 'dart:async';
import 'dart:convert';

import 'package:flutter/painting.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/auth/biometrics.dart';
import 'package:letter_signing/letters/letters_api.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/letters/models.dart';

/// A colleague as the directory returns it.
class FakeUser {
  const FakeUser(
    this.id,
    this.email, {
    this.permissions = const ['letter.see', 'letter.sign'],
  });
  final int id;
  final String email;
  final List<String> permissions;

  Map<String, dynamic> get directoryJson => {
    'id': id,
    'email': email,
    'full_name': email.split('@').first,
    'permissions': permissions,
  };
}

/// Scripted fingerprint/face: [result] is what `authenticate` returns.
class FakeBiometrics implements Biometrics {
  FakeBiometrics({this.isAvailable = true, this.result = true});
  final bool isAvailable;
  bool result;
  final reasons = <String>[];
  @override
  Future<bool> available() async => isAvailable;
  @override
  Future<bool> authenticate(String reason) async {
    reasons.add(reason);
    return result;
  }
}

/// A [LiveService] whose frames the test pushes by hand.
class FakeLive extends LiveService {
  FakeLive(ApiClient api) : super(api: api, cursor: MemoryCursorStore());
  final frames = StreamController<LiveEvent>.broadcast();
  final up = StreamController<bool>.broadcast();
  @override
  Stream<LiveEvent> get events => frames.stream;
  @override
  Stream<bool> get connection => up.stream;
  void push(Map<String, dynamic> frame) => frames.add(LiveEvent(frame));
}

LettersEnv testEnv(
  ({ApiClient client, LettersApi api, List<http.Request> calls}) f, {
  int userId = 2,
  Biometrics? biometrics,
  LiveService? live,
  Future<bool> Function(String pin)? enrollBiometric,
}) => LettersEnv(
  api: f.api,
  live: live ?? FakeLive(f.client),
  userId: userId,
  biometrics: biometrics ?? FakeBiometrics(),
  deviceName: 'laptop',
  enrollBiometric: enrollBiometric,
  sessionId: () => 'S1',
);

/// Tall surface so scrollable screens show everything.
Future<void> useTallSurface(
  WidgetTester t, [
  Size size = const Size(800, 2000),
]) async {
  t.view.devicePixelRatio = 1;
  await t.binding.setSurfaceSize(size);
  addTearDown(() {
    t.view.resetDevicePixelRatio();
    t.binding.setSurfaceSize(null);
  });
}

typedef Handler = http.Response Function(http.Request req, Object? body);

http.Response json(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// ApiClient + LettersApi on a scripted in-memory server. [handler] returns null to fall through to defaults.
({ApiClient client, LettersApi api, List<http.Request> calls}) fakeApi(
  Handler handler,
) {
  final calls = <http.Request>[];
  final mock = MockClient((req) async {
    calls.add(req);
    Object? body;
    if (req.body.isNotEmpty &&
        req.headers['content-type']?.contains('json') == true) {
      body = jsonDecode(req.body);
    }
    return handler(req, body);
  });
  final client = ApiClient(
    baseUrl: 'http://x',
    store: MemoryTokenStore(),
    client: mock,
  )..setSession(access: 'tok', refresh: 'r');
  return (
    client: client,
    api: LettersApi(client, httpClient: mock),
    calls: calls,
  );
}

Map<String, dynamic> briefJson(
  String id, {
  String status = 'draft',
  int no = 1,
  String? parentId,
  String title = 'T',
  int creator = 1,
  String visibility = 'private',
}) => {
  'id': id,
  'no': no,
  'title': title,
  'status': status,
  'creator_id': creator,
  'parent_id': parentId,
  'visibility': visibility,
  'unlisted': false,
  'created_at': '2026-01-01T00:00:00Z',
  'sent_at': null,
};

Map<String, dynamic> detailJson(
  Map<String, dynamic> brief, {
  Map<String, dynamic> body = const {'text': 'Hello', 'attachments': []},
  List<Map<String, dynamic>> participants = const [],
  List<Map<String, dynamic>> signatures = const [],
}) => {
  ...brief,
  'publish_mode': 'after_sign',
  'order': 'parallel',
  'due_at': null,
  'body': body,
  'participants': participants,
  'signatures': signatures,
  'children': [],
  'attachments': [],
};

Map<String, dynamic> signatureJson(
  FakeUser u, {
  String decision = 'approved',
  String method = 'pin',
  String device = 'laptop',
}) => {
  'signer_id': u.id,
  'decision': decision,
  'note': '',
  'method': method,
  'device_name': device,
  'signed_at': '2026-01-02T03:04:05Z',
  'seal': 'c2VhbA==',
  'payload': {'contentHash': 'h' * 64, 'method': method},
};

Map<String, dynamic> sessionJson(
  String id, {
  String device = 'phone',
  bool current = false,
  bool biometric = false,
  String platform = 'android',
}) => {
  'id': id,
  'device_name': device,
  'platform': platform,
  'ip': '1.2.3.4',
  'last_active': '2026-01-01T00:00:00Z',
  'current': current,
  'biometric': biometric,
};

Map<String, dynamic> signRequestJson(
  String id, {
  String status = 'pending',
  String decision = 'approved',
  String letterId = 'L1',
  String title = 'Budget',
  String note = 'ok',
  String approver = 'S2',
  String? expiresAt,
}) => {
  'id': id,
  'letter_id': letterId,
  'letter_title': title,
  'decision': decision,
  'note': note,
  'status': status,
  'requester_session_id': 'S1',
  'requester_device_name': 'laptop',
  'approver_session_id': approver,
  'created_at': '2026-01-01T00:00:00Z',
  'expires_at': expiresAt ?? '2999-01-01T00:00:00Z',
  'resolved_at': null,
};

Map<String, dynamic> participantJson(
  FakeUser u, {
  String role = 'signer',
  int position = 0,
  String decision = '',
}) => {
  'user_id': u.id,
  'email': u.email,
  'full_name': u.email.split('@').first,
  'role': role,
  'position': position,
  'decision': decision,
  'decided_at': null,
};
