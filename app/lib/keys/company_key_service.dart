import 'dart:typed_data';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/crypto/document_crypto.dart';
import 'package:letter_signing/keys/key_models.dart';
import 'package:letter_signing/keys/key_store.dart';
import 'package:letter_signing/keys/key_vault.dart';
import 'package:letter_signing/keys/keys_api.dart';

/// The company group key (roadmap 5.5), for public letters.
///
/// Wire formats:
/// - Company key: 32 random bytes, versioned (1, 2, ...); rotation = new version.
/// - Wrap of the company key for one user key (`CompanyKeyWrap.wrap`): `wrapDocKey` output,
///   `{to: key fingerprint, epk: ephemeral public JWK, iv, ct}` (ECDH P-256 + AES-GCM, AAD = fp).
/// - Wrap of a letter's document key under the company key (`company_wrap` on a letter):
///   `encryptBytes(docKey, companyKey)` = `{iv, ct}` base64 (AES-256-GCM, no AAD);
///   [wrapForCompany] returns it with the version as `{version, wrap: {iv, ct}}`.
class CompanyKeyService implements CompanyKeys {
  CompanyKeyService(ApiClient api, this.store) : _api = KeysApi(api);

  final KeyStore store;
  final KeysApi _api;

  @override
  Future<Uint8List?> get(int version, UnlockedKey key) async {
    final wraps = await _api.companyMine();
    for (final w in wraps) {
      if (w.version == version && w.keyId == key.keyId) {
        return unwrapDocKey(w.wrap, key.identity.encJwk, key.identity.fp);
      }
    }
    return null;
  }

  @override
  Future<({int version, Map<String, dynamic> wrap})?> wrapForCompany(
    Uint8List docKey,
    UnlockedKey key,
  ) async {
    final version = await _api.companyVersion();
    if (version == 0) return null;
    final companyKey = await get(version, key);
    if (companyKey == null) return null;
    return (version: version, wrap: encryptBytes(docKey, companyKey));
  }

  Map<String, dynamic> _wrapFor(Uint8List companyKey, UserKeyInfo k) =>
      wrapDocKey(companyKey, k.encPub, k.fingerprint);

  /// Manager only: creates the next version with a fresh random key, wrapped for every active
  /// key in the directory. Returns the new version.
  Future<int> createOrRotateCompanyKey(UnlockedKey manager) async {
    final version = await _api.companyVersion() + 1;
    final keys = [for (final u in await _api.directory()) ...u.keys];
    if (!keys.any((k) => k.id == manager.keyId)) {
      throw const KeyException('Your key is not active');
    }
    final companyKey = newDocKey();
    await _api.setCompanyKey(version, [
      for (final k in keys) (keyId: k.id, wrap: _wrapFor(companyKey, k)),
    ]);
    return version;
  }

  /// Manager only: wraps the current company key for active keys that lack it (new members or
  /// devices). Needs the manager's own wrap of the current version. Returns how many were added.
  Future<int> onboardMissing(UnlockedKey manager) async {
    final version = await _api.companyVersion();
    if (version == 0) return 0;
    final missing = await _api.companyMissing();
    if (missing.isEmpty) return 0;
    final companyKey = await get(version, manager);
    if (companyKey == null) {
      throw const KeyException('This device has no copy of the company key');
    }
    await _api.setCompanyKey(version, [
      for (final k in missing) (keyId: k.id, wrap: _wrapFor(companyKey, k)),
    ]);
    return missing.length;
  }
}
