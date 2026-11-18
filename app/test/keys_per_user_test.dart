import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/crypto/identity.dart';
import 'package:letter_signing/keys/key_store.dart';
import 'package:letter_signing/keys/secure_kv.dart';

void main() {
  test('accounts on one device keep separate keys and legacy keys are adopted by their owner', () async {
    final kv = MemoryKv();
    final alice = KeyStore(kv: kv, userId: 1);
    final bob = KeyStore(kv: kv, userId: 2);
    await alice.save(
      identity: Identity.generate('alice'),
      keyId: 'key-a',
      protection: KeyProtection.password,
      password: 'Str0ng-Passw0rd!',
    );
    expect((await alice.load())?.keyId, 'key-a');
    expect(await bob.load(), isNull); // another account sees nothing

    // a key stored by an older build (no account prefix)
    final legacy = KeyStore(kv: kv);
    await legacy.save(
      identity: Identity.generate('bob'),
      keyId: 'key-b',
      protection: KeyProtection.password,
      password: 'Str0ng-Passw0rd!',
    );
    expect(await alice.adoptDeviceKey({'someone-else'}), isFalse);
    expect(await bob.adoptDeviceKey({'key-b'}), isTrue);
    expect((await bob.load())?.keyId, 'key-b');
    expect(await legacy.load(), isNull);
    expect((await alice.load())?.keyId, 'key-a'); // untouched
  }, timeout: const Timeout(Duration(minutes: 2)));
}
