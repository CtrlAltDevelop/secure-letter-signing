import 'package:flutter/foundation.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/crypto/document_crypto.dart';
import 'package:letter_signing/crypto/crypto_primitives.dart';
import 'package:letter_signing/keys/key_vault.dart';
import 'package:letter_signing/letters/letter_crypto_service.dart';
import 'package:letter_signing/letters/letters_api.dart';
import 'package:letter_signing/letters/models.dart';

@immutable
class RewrapResult {
  const RewrapResult({required this.done, required this.failed});
  final int done;

  /// letterId -> reason, for letters this device could not re-wrap (shown, never swallowed).
  final Map<String, String> failed;
}

/// After the user unlocks a key: gives newly approved keys of participants access to letters this device can read.
class RewrapService {
  RewrapService({required this.api, required this.crypto});

  final LettersApi api;
  final LetterCryptoService crypto;

  Future<RewrapResult> run(UnlockedKey key) async {
    final byLetter = <String, List<KeyInfo>>{};
    for (final item in await api.rewrapNeeded()) {
      byLetter.putIfAbsent(item.letterId, () => []).add(item.key);
    }
    var done = 0;
    final failed = <String, String>{};
    for (final entry in byLetter.entries) {
      try {
        final docKey = await crypto.documentKey(
          await api.detail(entry.key),
          key,
        );
        await api.addWraps(entry.key, [
          for (final k in entry.value)
            WrapEntry(
              keyId: k.id,
              wrap: wrapDocKey(docKey, k.encPub, k.fingerprint),
            ),
        ]);
        done++;
      } on LetterException catch (e) {
        failed[entry.key] = e.message;
      } on CryptoException catch (e) {
        failed[entry.key] = e.message;
      } on ApiException catch (e) {
        failed[entry.key] = e.message;
      }
    }
    return RewrapResult(done: done, failed: failed);
  }
}
