import 'package:letter_signing/crypto/identity.dart';
import 'package:letter_signing/keys/key_models.dart';
import 'package:letter_signing/keys/key_store.dart';
import 'package:letter_signing/keys/keys_api.dart';
import 'package:letter_signing/keys/transfer_codec.dart';

/// Moves a password-protected key between devices (roadmap 5.3). Pure logic, no UI.
class KeyTransfer {
  const KeyTransfer(this.store, this.api);
  final KeyStore store;
  final KeysApi api;

  /// Re-checks the key password, reports the export to the server (audit), then returns the
  /// envelope text for file/QR. Refuses biometric-sealed keys.
  Future<String> export(String password) async {
    final key = await store.load();
    if (key == null) throw const KeyException('This device has no key');
    if (key.sealed) {
      throw const KeyException(
        'A biometric-sealed key cannot be exported. Create a new key on the other device.',
      );
    }
    await store.unlockWithPassword(key, password);
    await api.transferEvent(key.keyId, 'export');
    return KeyEnvelope(keyId: key.keyId, keyFile: key.keyFile).encode();
  }

  /// Verifies [password] against the envelope (same password as on the old device), checks the
  /// key is this user's active server key, reports the import, then saves it locally.
  Future<StoredKey> import(String envelopeText, String password) async {
    final env = KeyEnvelope.decode(envelopeText);
    final Identity identity = await Identity.unwrap(env.keyFile, password);
    final mine = await api.mine();
    final server = mine.where((k) => k.id == env.keyId && k.isActive);
    if (server.isEmpty || server.first.fingerprint != identity.fp) {
      throw const KeyException(
        'This key is not an active key of your account',
      );
    }
    await api.transferEvent(env.keyId, 'import');
    return store.saveWrapped(env.keyId, env.keyFile);
  }
}
