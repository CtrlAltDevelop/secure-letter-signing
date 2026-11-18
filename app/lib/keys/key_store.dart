import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:letter_signing/crypto/crypto_primitives.dart';
import 'package:letter_signing/crypto/identity.dart';
import 'package:letter_signing/keys/attempt_limiter.dart';
import 'package:letter_signing/keys/key_models.dart';
import 'package:letter_signing/keys/secure_kv.dart';

enum KeyProtection {
  /// Wrapped with a random secret that is released only after a biometric check. Never exportable.
  sealed,

  /// Wrapped with a strong user password. Transferable by QR/file.
  password,
}

/// The key this device holds: [keyFile] is `Identity.wrap` output (no plaintext private key).
@immutable
class StoredKey {
  const StoredKey({
    required this.keyId,
    required this.keyFile,
    required this.sealed,
  });
  final String keyId;
  final Map<String, dynamic> keyFile;
  final bool sealed;

  String get fingerprint =>
      (keyFile['pub'] as Map<String, dynamic>)['fp'] as String;
}

/// Everything persisted about this device's key, on top of [SecureKv].
/// One key per device. The server decides whether it is active.
class KeyStore {
  KeyStore({
    SecureKv? kv,
    Biometrics? biometrics,
    DateTime Function()? clock,
  }) : kv = kv ?? const FlutterSecureKv(),
       biometrics = biometrics ?? const LocalAuthBiometrics() {
    attempts = AttemptLimiter(this.kv, clock: clock);
  }

  final SecureKv kv;
  final Biometrics biometrics;
  late final AttemptLimiter attempts;

  static const _fileKey = 'key.file';
  static const _idKey = 'key.id';
  static const _sealedKey = 'key.sealed';
  static const _secretKey = 'key.secret';
  static const _pinsKey = 'key.pins';

  Future<StoredKey?> load() async {
    final file = await kv.read(_fileKey);
    final id = await kv.read(_idKey);
    if (file == null || id == null) return null;
    return StoredKey(
      keyId: id,
      keyFile: jsonDecode(file) as Map<String, dynamic>,
      sealed: await kv.read(_sealedKey) == '1',
    );
  }

  /// Biometric protection is the default when the device has biometrics.
  Future<KeyProtection> defaultProtection() async =>
      await biometrics.available()
      ? KeyProtection.sealed
      : KeyProtection.password;

  /// Protects [identity] per [protection] (a [password] is required for [KeyProtection.password])
  /// and stores it under the server's [keyId].
  Future<StoredKey> save({
    required Identity identity,
    required String keyId,
    required KeyProtection protection,
    String? password,
  }) async {
    final sealed = protection == KeyProtection.sealed;
    final Uint8List? secret = sealed ? randomBytes(32) : null;
    if (!sealed && (password == null || !strongKeyPassword(password))) {
      throw const KeyException('Password is not strong enough');
    }
    final keyFile = await identity.wrap(
      sealed ? base64.encode(secret!) : password!,
    );
    await clear();
    await kv.write(_fileKey, jsonEncode(keyFile));
    await kv.write(_idKey, keyId);
    await kv.write(_sealedKey, sealed ? '1' : '0');
    if (secret != null) await kv.write(_secretKey, base64.encode(secret));
    return StoredKey(keyId: keyId, keyFile: keyFile, sealed: sealed);
  }

  /// Stores an already-wrapped, password-protected [keyFile] (transfer import).
  Future<StoredKey> saveWrapped(String keyId, Map<String, dynamic> keyFile) async {
    await clear();
    await kv.write(_fileKey, jsonEncode(keyFile));
    await kv.write(_idKey, keyId);
    await kv.write(_sealedKey, '0');
    return StoredKey(keyId: keyId, keyFile: keyFile, sealed: false);
  }

  Future<void> clear() async {
    for (final k in [_fileKey, _idKey, _sealedKey, _secretKey]) {
      await kv.delete(k);
    }
    await attempts.reset();
  }

  /// Unlocks a sealed key: runs the biometric check, then unwraps with the stored secret.
  /// Returns null if the check failed or was cancelled.
  Future<Identity?> unlockSealed(StoredKey key, String reason) async {
    if (!key.sealed) throw const KeyException('Key is password protected');
    final secret = await kv.read(_secretKey);
    if (secret == null) throw const KeyException('Sealed secret is missing');
    if (!await biometrics.authenticate(reason)) return null;
    return Identity.unwrap(key.keyFile, secret);
  }

  /// Unwraps a password-protected key with brute-force accounting: throws [KeyLockedException]
  /// while a delay is running, [WrongPasswordException] (and counts it) on a bad password.
  Future<Identity> unlockWithPassword(StoredKey key, String password) async {
    if (key.sealed) throw const KeyException('Key is sealed to this device');
    final wait = await attempts.remaining();
    if (wait > Duration.zero) throw KeyLockedException(wait);
    try {
      final identity = await Identity.unwrap(key.keyFile, password);
      await attempts.reset();
      return identity;
    } on WrongPasswordException {
      await attempts.recordFailure();
      rethrow;
    }
  }

  /// Last-seen fingerprint of each of the user's own keys (keyId -> fp).
  Future<Map<String, String>> pinnedFingerprints() async {
    final raw = await kv.read(_pinsKey);
    return raw == null
        ? const {}
        : Map<String, String>.from(jsonDecode(raw) as Map);
  }

  /// Pins [keyId]'s fingerprint on first sight. Returns false if it differs from the pinned one
  /// (the pin is kept, so the warning persists until the user resets it).
  Future<bool> checkPin(String keyId, String fingerprint) async {
    final pins = await pinnedFingerprints();
    final pinned = pins[keyId];
    if (pinned != null) return pinned == fingerprint;
    await kv.write(_pinsKey, jsonEncode({...pins, keyId: fingerprint}));
    return true;
  }

  /// The user accepted a changed fingerprint.
  Future<void> repin(String keyId, String fingerprint) async => kv.write(
    _pinsKey,
    jsonEncode({...await pinnedFingerprints(), keyId: fingerprint}),
  );
}
