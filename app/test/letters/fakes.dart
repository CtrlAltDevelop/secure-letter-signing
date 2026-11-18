import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/crypto/document_crypto.dart';
import 'package:letter_signing/crypto/identity.dart';
import 'package:letter_signing/keys/key_vault.dart';
import 'package:letter_signing/letters/letters_api.dart';

const kCompanyKey = 'company';

/// A user with one active key, as the directory returns it.
class FakeUser {
  FakeUser(this.id, this.email, {this.permissions = const ['letter.see', 'letter.sign']})
    : identity = Identity.generate(email),
      keyId = '00000000-0000-0000-0000-${id.toString().padLeft(12, '0')}';
  final int id;
  final String email;
  final List<String> permissions;
  final Identity identity;
  final String keyId;

  UnlockedKey get unlocked => UnlockedKey(keyId: keyId, identity: identity);

  Map<String, dynamic> get directoryJson => {
    'id': id,
    'email': email,
    'full_name': email.split('@').first,
    'permissions': permissions,
    'keys': [
      {
        'id': keyId,
        'user_id': id,
        'device_name': 'phone',
        'sign_pub': identity.publicFile['sign'],
        'enc_pub': identity.publicFile['enc'],
        'fingerprint': identity.fp,
        'status': 'active',
        'created_at': '2026-01-01T00:00:00Z',
      },
    ],
  };
}

class FakeVault implements KeyVault {
  FakeVault(this.key);
  UnlockedKey? key;
  final reasons = <String>[];
  @override
  Future<bool> hasActiveKey() async => key != null;
  @override
  Future<UnlockedKey?> unlock(BuildContext context, {required String reason}) async {
    reasons.add(reason);
    return key;
  }
}

/// Wraps are plain AES-GCM under a fixed company key (matches `decryptBytes` in the service).
class FakeCompanyKeys implements CompanyKeys {
  FakeCompanyKeys({this.empty = false});
  final bool empty;
  final Uint8List key = Uint8List.fromList(List.filled(32, 7));
  @override
  Future<Uint8List?> get(int version, UnlockedKey k) async => version == 1 ? key : null;
  @override
  Future<({int version, Map<String, dynamic> wrap})?> wrapForCompany(Uint8List docKey, UnlockedKey k) async =>
      empty ? null : (version: 1, wrap: encryptBytes(docKey, key));
}

typedef Handler = http.Response Function(http.Request req, Object? body);

http.Response json(Object? body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

/// ApiClient + LettersApi on a scripted in-memory server. [handler] returns null to fall through to defaults.
({ApiClient client, LettersApi api, List<http.Request> calls}) fakeApi(Handler handler) {
  final calls = <http.Request>[];
  final mock = MockClient((req) async {
    calls.add(req);
    Object? body;
    if (req.body.isNotEmpty && req.headers['content-type']?.contains('json') == true) {
      body = jsonDecode(req.body);
    }
    return handler(req, body);
  });
  final client = ApiClient(baseUrl: 'http://x', store: MemoryTokenStore(), client: mock)
    ..setSession(access: 'tok', refresh: 'r');
  return (client: client, api: LettersApi(client, httpClient: mock), calls: calls);
}

Map<String, dynamic> briefJson(String id, {String status = 'draft', int no = 1, String? parentId, String title = 'T', int creator = 1, String visibility = 'private'}) => {
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
  required Map<String, dynamic> body,
  List<Map<String, dynamic>> participants = const [],
  List<Map<String, dynamic>> myWraps = const [],
  Map<String, dynamic>? companyWrap,
  int order = 0,
}) => {
  ...brief,
  'publish_mode': 'after_sign',
  'order': 'parallel',
  'due_at': null,
  'body': body,
  'company_key_version': companyWrap == null ? null : 1,
  'company_wrap': companyWrap,
  'participants': participants,
  'signatures': [],
  'my_wraps': myWraps,
  'children': [],
  'attachments': [],
};

Map<String, dynamic> participantJson(FakeUser u, {String role = 'signer', int position = 0, String decision = ''}) => {
  'user_id': u.id,
  'email': u.email,
  'full_name': u.email.split('@').first,
  'role': role,
  'position': position,
  'decision': decision,
  'decided_at': null,
};
