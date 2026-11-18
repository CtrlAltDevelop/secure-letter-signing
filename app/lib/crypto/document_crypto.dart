import 'dart:convert';
import 'dart:typed_data';

import 'crypto_primitives.dart';
import 'letter_crypto.dart';

/// A 32-byte document key wrapped for one recipient:
/// `{to: recipient fp, epk: ephemeral public JWK, iv, ct}` (base64, ct = AES-GCM(key) with AAD = fp).
Map<String, dynamic> wrapDocKey(
  Uint8List docKey,
  Map<String, dynamic> recipientEncJwk,
  String recipientFp,
) {
  if (docKey.length != 32)
    throw const CryptoException('Document key must be 32 bytes');
  final eph = generateP256Jwk();
  final aes = deriveAesKey(eph.priv, recipientEncJwk);
  final iv = randomBytes(12);
  final ct = aesGcm(true, aes, iv, docKey, utf8Bytes(recipientFp));
  return {
    'to': recipientFp,
    'epk': eph.pub,
    'iv': base64.encode(iv),
    'ct': base64.encode(ct),
  };
}

/// Inverse of [wrapDocKey]; throws [DecryptionException] if tampered or not for [fp].
Uint8List unwrapDocKey(
  Map<String, dynamic> wrapped,
  Map<String, dynamic> encPrivateJwk,
  String fp,
) {
  if (wrapped['to'] != fp)
    throw const DecryptionException('Key is wrapped for another recipient');
  final aes = deriveAesKey(
    encPrivateJwk,
    wrapped['epk'] as Map<String, dynamic>,
  );
  return aesGcm(
    false,
    aes,
    base64.decode(wrapped['iv'] as String),
    base64.decode(wrapped['ct'] as String),
    utf8Bytes(fp),
  );
}

Uint8List newDocKey() => randomBytes(32);

/// AES-256-GCM, fresh 12-byte IV. Returns `{iv, ct}` base64.
Map<String, String> encryptBytes(Uint8List plain, Uint8List docKey) {
  final iv = randomBytes(12);
  return {
    'iv': base64.encode(iv),
    'ct': base64.encode(aesGcm(true, docKey, iv, plain)),
  };
}

Uint8List decryptBytes(Map<String, dynamic> box, Uint8List docKey) => aesGcm(
  false,
  docKey,
  base64.decode(box['iv'] as String),
  base64.decode(box['ct'] as String),
);

/// JSON is encoded as canonical JSON (sorted keys, no floats), matching JS `canon`.
Map<String, String> encryptJson(Object? value, Uint8List docKey) =>
    encryptBytes(utf8Bytes(canonicalJson(value)), docKey);

Object? decryptJson(Map<String, dynamic> box, Uint8List docKey) =>
    jsonDecode(utf8.decode(decryptBytes(box, docKey)));

/// ECDSA signature (base64 r||s) over the canonical JSON of [payload]. Payload must not contain floats.
String signPayload(
  Map<String, dynamic> payload,
  Map<String, dynamic> signPrivateJwk,
) =>
    base64.encode(signBytes(utf8Bytes(canonicalJson(payload)), signPrivateJwk));

bool verifyPayload(
  Map<String, dynamic> payload,
  String sigB64,
  Map<String, dynamic> signPublicJwk,
) => verifyBytes(
  utf8Bytes(canonicalJson(payload)),
  base64.decode(sigB64),
  signPublicJwk,
);
