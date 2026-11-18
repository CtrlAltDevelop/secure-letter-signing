import 'dart:convert';
import 'dart:io' show zlib;
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'package:letter_signing/crypto/crypto_primitives.dart';
import 'package:letter_signing/crypto/document_crypto.dart';
import 'package:letter_signing/crypto/letter_crypto.dart';
import 'package:letter_signing/keys/key_vault.dart';

/// SHA-256 hex of the canonical JSON of the encrypted body `{iv, ct}`: what a signature binds to.
String contentHashOf(Map<String, dynamic> body) => hexOf(
  SHA256Digest().process(
    Uint8List.fromList(utf8.encode(canonicalJson({'iv': body['iv'], 'ct': body['ct']}))),
  ),
);

/// UTC ISO-8601 with an explicit offset and whole seconds, e.g. 2026-01-02T03:04:05+00:00.
String signedAtString(DateTime t) {
  final iso = t.toUtc().toIso8601String().split('.').first;
  return '${iso.endsWith('Z') ? iso.substring(0, iso.length - 1) : iso}+00:00';
}

String newNonce() => hexOf(randomBytes(16));

/// The exact payload `letters/api.py::_check_payload` verifies. No floats, nothing beside it.
Map<String, dynamic> buildSignPayload({
  required String letterId,
  required String title,
  required String? parentId,
  required Map<String, dynamic> body,
  required String decision,
  required String note,
  required int userId,
  required String keyId,
  required String fingerprint,
  required String sessionId,
  required String deviceName,
  DateTime? now,
  String? nonce,
}) => {
  'letterId': letterId,
  'title': title,
  'parentId': parentId,
  'decision': decision,
  'note': note,
  'contentHash': contentHashOf(body),
  'signer': {'userId': userId, 'keyId': keyId, 'fp': fingerprint},
  'sessionId': sessionId,
  'deviceName': deviceName,
  'signedAt': signedAtString(now ?? DateTime.now()),
  'nonce': nonce ?? newNonce(),
};

/// Signs with the unlocked key; returns the signature for `POST /letters/{id}/sign`.
String signDecision(Map<String, dynamic> payload, UnlockedKey key) =>
    signPayload(payload, key.identity.signJwk);

/// Session id embedded in the opaque access token (`base64(json {"s": id})[:ts:sig]`, `.`-prefixed if zlib-compressed).
String? sessionIdFromAccessToken(String? token) {
  if (token == null) return null;
  var part = token.split(':').first;
  final compressed = part.startsWith('.');
  if (compressed) part = part.substring(1);
  try {
    var bytes = base64Url.decode(base64Url.normalize(part));
    if (compressed) bytes = Uint8List.fromList(zlib.decode(bytes));
    return (jsonDecode(utf8.decode(bytes)) as Map)['s'] as String?;
  } on Object {
    return null;
  }
}
