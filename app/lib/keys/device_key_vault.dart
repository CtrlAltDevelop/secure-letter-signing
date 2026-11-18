import 'package:flutter/widgets.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/keys/key_store.dart';
import 'package:letter_signing/keys/key_vault.dart';
import 'package:letter_signing/keys/keys_api.dart';
import 'package:letter_signing/keys/password_prompt.dart';

/// [KeyVault] backed by this device's [KeyStore] and the server's key status.
class DeviceKeyVault implements KeyVault {
  DeviceKeyVault(ApiClient api, this.store) : _api = KeysApi(api);

  final KeyStore store;
  final KeysApi _api;

  Future<bool> _isActive(StoredKey stored) async =>
      (await _api.mine()).any((k) => k.id == stored.keyId && k.isActive);

  @override
  Future<bool> hasActiveKey() async {
    final stored = await store.load();
    return stored != null && await _isActive(stored);
  }

  @override
  Future<UnlockedKey?> unlock(
    BuildContext context, {
    required String reason,
  }) async {
    final stored = await store.load();
    if (stored == null || !await _isActive(stored)) return null;
    if (!context.mounted) return null;
    final identity = stored.sealed
        ? await store.unlockSealed(stored, reason)
        : await showPasswordPrompt(
            context,
            title: 'Unlock your key',
            reason: reason,
            verify: (pw) => store.unlockWithPassword(stored, pw),
          );
    return identity == null
        ? null
        : UnlockedKey(keyId: stored.keyId, identity: identity);
  }
}
