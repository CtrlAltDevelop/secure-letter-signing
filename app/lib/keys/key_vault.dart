import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'package:letter_signing/crypto/identity.dart';

/// A private key unwrapped in memory for one operation. Never store or log it.
@immutable
class UnlockedKey {
  const UnlockedKey({required this.keyId, required this.identity});

  /// Server-side id of this device's key (UserKey.id).
  final String keyId;
  final Identity identity;
}

/// The contract between the letter screens and key management.
/// Every signature needs a fresh unlock (biometric where available, else the key password).
abstract interface class KeyVault {
  /// True when this device holds a key that the server has approved (status "active").
  Future<bool> hasActiveKey();

  /// Asks the user to unlock this device's key (biometric/password prompt) and returns it,
  /// or null if the user cancelled or the key is missing/unapproved.
  Future<UnlockedKey?> unlock(BuildContext context, {required String reason});
}

/// The company group key (public letters). Implemented by the key layer, used by the letter layer.
abstract interface class CompanyKeys {
  /// Company key of [version] (null if this device has no wrap for it yet), unwrapped with [key].
  Future<Uint8List?> get(int version, UnlockedKey key);

  /// Wraps a letter's document key under the newest company key: `{version, wrap: {iv, ct}}`; null if none exists.
  Future<({int version, Map<String, dynamic> wrap})?> wrapForCompany(
    Uint8List docKey,
    UnlockedKey key,
  );
}
