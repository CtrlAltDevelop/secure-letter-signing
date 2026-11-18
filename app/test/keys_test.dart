import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/crypto/crypto_primitives.dart';
import 'package:letter_signing/crypto/document_crypto.dart';
import 'package:letter_signing/crypto/identity.dart';
import 'package:letter_signing/keys/attempt_limiter.dart';
import 'package:letter_signing/keys/company_key_service.dart';
import 'package:letter_signing/keys/key_models.dart';
import 'package:letter_signing/keys/key_store.dart';
import 'package:letter_signing/keys/key_transfer.dart';
import 'package:letter_signing/keys/key_vault.dart';
import 'package:letter_signing/keys/keys_api.dart';
import 'package:letter_signing/keys/password_strength.dart';
import 'package:letter_signing/keys/secure_kv.dart';
import 'package:letter_signing/keys/transfer_codec.dart';

const _password = 'Str0ng!Passw0rd';

class FakeBiometrics implements Biometrics {
  FakeBiometrics({this.isAvailable = true, this.accepts = true});
  final bool isAvailable;
  final bool accepts;
  @override
  Future<bool> available() async => isAvailable;
  @override
  Future<bool> authenticate(String reason) async => accepts;
}

/// In-memory stand-in for the `/api/keys` endpoints.
class FakeKeysServer {
  final List<Map<String, dynamic>> keys = [];
  final List<String> events = [];
  final Map<int, Map<String, Map<String, dynamic>>> company = {};

  void addKey(String id, Identity identity, {String status = 'active'}) =>
      keys.add({
        'id': id,
        'user_id': 1,
        'device_name': identity.name,
        'sign_pub': identity.publicFile['sign'],
        'enc_pub': identity.publicFile['enc'],
        'fingerprint': identity.fp,
        'status': status,
      });

  int get _version => company.keys.fold(0, (a, b) => a > b ? a : b);

  http.Response _json(Object body) => http.Response(jsonEncode(body), 200);

  Future<http.Response> handle(http.Request r) async {
    final path = r.url.path.replaceFirst('/api/keys', '');
    final body = r.body.isEmpty ? null : jsonDecode(r.body);
    final transfer = RegExp(r'^/([^/]+)/transfer-event$').firstMatch(path);
    if (transfer != null) {
      events.add((body as Map)['kind'] as String);
      return _json({'detail': 'Recorded'});
    }
    switch ('${r.method} $path') {
      case 'GET /mine':
        return _json(keys);
      case 'GET /directory':
        return _json([
          {
            'id': 1,
            'email': 'a@x.test',
            'full_name': 'A',
            'keys': keys.where((k) => k['status'] == 'active').toList(),
          },
        ]);
      case 'GET /company/status':
        return _json({'version': _version, 'needs_rotation': false});
      case 'GET /company/mine':
        return _json([
          for (final v in company.keys)
            for (final e in company[v]!.entries)
              {'version': v, 'key_id': e.key, 'wrap': e.value},
        ]);
      case 'GET /company/missing':
        final have = company[_version]?.keys.toSet() ?? {};
        return _json([
          for (final k in keys)
            if (k['status'] == 'active' && !have.contains(k['id'])) k,
        ]);
      case 'POST /company':
        final b = body as Map<String, dynamic>;
        final into = company.putIfAbsent(b['version'] as int, () => {});
        for (final w in b['wraps'] as List) {
          into[w['key_id'] as String] = Map<String, dynamic>.from(w['wrap']);
        }
        return _json({'version': b['version'], 'needs_rotation': false});
    }
    return http.Response(jsonEncode({'detail': 'not found'}), 404);
  }
}

ApiClient _api(FakeKeysServer server) => ApiClient(
  baseUrl: 'http://x',
  store: MemoryTokenStore(),
  client: MockClient(server.handle),
);

void main() {
  group('password strength gate', () {
    test('accepts only passwords with all five rules', () {
      expect(strongKeyPassword(_password), isTrue);
      for (final weak in [
        'short1A!',
        'alllowercase1!',
        'NOLOWER1234!',
        'NoDigitsHere!',
        'NoSymbol12345A',
      ]) {
        expect(strongKeyPassword(weak), isFalse, reason: weak);
      }
    });

    test('meter reaches 1.0 exactly when the password is strong', () {
      expect(passwordStrength(''), 0);
      expect(passwordStrength('abc'), lessThan(1));
      expect(passwordStrength(_password), 1);
    });
  });

  group('brute-force protection', () {
    test('no delay for 9 failures, then 30 s doubling, capped at 24 h', () {
      expect(lockoutFor(9), Duration.zero);
      expect(lockoutFor(10), const Duration(seconds: 30));
      expect(lockoutFor(11), const Duration(minutes: 1));
      expect(lockoutFor(12), const Duration(minutes: 2));
      expect(lockoutFor(500), const Duration(hours: 24));
    });

    test('locks after 10 failures, persists, expires, and resets', () async {
      var now = DateTime(2026);
      final kv = MemoryKv();
      final limiter = AttemptLimiter(kv, clock: () => now);
      for (var i = 0; i < 9; i++) {
        await limiter.recordFailure();
      }
      expect(await limiter.remaining(), Duration.zero);
      await limiter.recordFailure();
      expect(await limiter.remaining(), const Duration(seconds: 30));

      final reopened = AttemptLimiter(kv, clock: () => now); // "app restart"
      expect(await reopened.remaining(), const Duration(seconds: 30));
      now = now.add(const Duration(seconds: 31));
      expect(await reopened.remaining(), Duration.zero);

      await reopened.recordFailure();
      expect(await reopened.remaining(), const Duration(minutes: 1));
      await reopened.reset();
      expect(await reopened.failures(), 0);
      expect(await reopened.remaining(), Duration.zero);
    });
  });

  group('QR framing', () {
    test(
      'splits a large envelope and joins it from shuffled, duplicated frames',
      () {
        final envelope = jsonEncode({
          'v': 1,
          'keyId': 'k',
          'keyFile': {'ct': base64.encode(randomBytes(3000))},
        });
        final frames = splitQrFrames(envelope);
        expect(frames.length, greaterThan(1));
        var assembler = const QrAssembler.empty().add('not a frame');
        for (final f in [
          ...frames.reversed.skip(1),
          frames.first,
          frames.first,
        ]) {
          assembler = assembler.add(f);
        }
        expect(assembler.complete, isFalse);
        assembler = assembler.add(frames.last);
        expect(assembler.complete, isTrue);
        expect(assembler.join(), envelope);
      },
    );

    test('a frame of another transfer restarts assembly', () {
      final a = splitQrFrames('a' * 2000);
      final b = splitQrFrames('b' * 2000);
      final mixed = const QrAssembler.empty().add(a[0]).add(b[1]);
      expect(mixed.received, 1);
      expect(() => mixed.join(), throwsA(isA<KeyException>()));
    });

    test('envelope rejects junk', () {
      expect(() => KeyEnvelope.decode('{"v":2}'), throwsA(isA<KeyException>()));
      expect(() => KeyEnvelope.decode('nope'), throwsA(isA<KeyException>()));
    });
  });

  group('key store and transfer (real 600k-iteration KDF)', () {
    test(
      'export/import round trip keeps keyId, same password required',
      () async {
        final server = FakeKeysServer();
        final identity = Identity.generate('Phone');
        server.addKey('key-1', identity);
        final storeA = KeyStore(
          kv: MemoryKv(),
          biometrics: FakeBiometrics(isAvailable: false),
        );
        expect(await storeA.defaultProtection(), KeyProtection.password);
        await storeA.save(
          identity: identity,
          keyId: 'key-1',
          protection: KeyProtection.password,
          password: _password,
        );
        final transferA = KeyTransfer(storeA, KeysApi(_api(server)));

        await expectLater(
          transferA.export('Wr0ng!Passw0rd'),
          throwsA(isA<WrongPasswordException>()),
        );
        expect(await storeA.attempts.failures(), 1);
        expect(server.events, isEmpty);
        final envelope = await transferA.export(_password);
        expect(await storeA.attempts.failures(), 0);
        expect(server.events, ['export']);

        final storeB = KeyStore(kv: MemoryKv());
        final transferB = KeyTransfer(storeB, KeysApi(_api(server)));
        await expectLater(
          transferB.import(envelope, 'Wr0ng!Passw0rd'),
          throwsA(isA<WrongPasswordException>()),
        );
        expect(await storeB.load(), isNull);

        final saved = await transferB.import(envelope, _password);
        expect(saved.keyId, 'key-1');
        expect(saved.sealed, isFalse);
        expect(server.events, ['export', 'import']);
        final unlocked = await storeB.unlockWithPassword(
          (await storeB.load())!,
          _password,
        );
        expect(unlocked.fp, identity.fp);
      },
    );

    test(
      'import refuses a key that is not an active key of the account',
      () async {
        final server = FakeKeysServer();
        final identity = Identity.generate('Phone');
        server.addKey('key-1', identity, status: 'retired');
        final store = KeyStore(kv: MemoryKv());
        final env = KeyEnvelope(
          keyId: 'key-1',
          keyFile: await identity.wrap(_password),
        ).encode();
        await expectLater(
          KeyTransfer(store, KeysApi(_api(server))).import(env, _password),
          throwsA(isA<KeyException>()),
        );
        expect(await store.load(), isNull);
      },
    );

    test('sealed key unlocks by biometrics and refuses export', () async {
      final server = FakeKeysServer();
      final identity = Identity.generate('Phone');
      server.addKey('key-1', identity);
      final kv = MemoryKv();
      final store = KeyStore(kv: kv, biometrics: FakeBiometrics());
      expect(await store.defaultProtection(), KeyProtection.sealed);
      final stored = await store.save(
        identity: identity,
        keyId: 'key-1',
        protection: KeyProtection.sealed,
      );
      expect(stored.sealed, isTrue);

      await expectLater(
        KeyTransfer(store, KeysApi(_api(server))).export(_password),
        throwsA(isA<KeyException>()),
      );
      expect(server.events, isEmpty);
      expect((await store.unlockSealed(stored, 'sign'))?.fp, identity.fp);
      final denied = KeyStore(
        kv: kv,
        biometrics: FakeBiometrics(accepts: false),
      );
      expect(await denied.unlockSealed(stored, 'sign'), isNull);
      await expectLater(
        store.unlockWithPassword(stored, _password),
        throwsA(isA<KeyException>()),
      );
    });

    test('weak passwords are refused when saving', () async {
      final store = KeyStore(kv: MemoryKv());
      await expectLater(
        store.save(
          identity: Identity.generate('x'),
          keyId: 'k',
          protection: KeyProtection.password,
          password: 'weak',
        ),
        throwsA(isA<KeyException>()),
      );
    });

    test('fingerprint pin warns on a changed fingerprint', () async {
      final store = KeyStore(kv: MemoryKv());
      expect(await store.checkPin('k', 'AAAA'), isTrue);
      expect(await store.checkPin('k', 'AAAA'), isTrue);
      expect(await store.checkPin('k', 'BBBB'), isFalse);
      await store.repin('k', 'BBBB');
      expect(await store.checkPin('k', 'BBBB'), isTrue);
    });
  });

  group('company key', () {
    test(
      'create, unwrap, wrap a document key, onboard a missing key',
      () async {
        final server = FakeKeysServer();
        final manager = Identity.generate('Manager');
        final member = Identity.generate('Member');
        server.addKey('km', manager);
        server.addKey('ku', member);
        final service = CompanyKeyService(
          _api(server),
          KeyStore(kv: MemoryKv()),
        );
        final managerKey = UnlockedKey(keyId: 'km', identity: manager);
        final memberKey = UnlockedKey(keyId: 'ku', identity: member);

        expect(await service.wrapForCompany(newDocKey(), managerKey), isNull);
        expect(await service.createOrRotateCompanyKey(managerKey), 1);

        final companyKey = await service.get(1, memberKey);
        expect(companyKey, equals(await service.get(1, managerKey)));
        expect(companyKey, hasLength(32));

        final docKey = newDocKey();
        final wrapped = (await service.wrapForCompany(docKey, memberKey))!;
        expect(wrapped.version, 1);
        expect(decryptBytes(wrapped.wrap, companyKey!), docKey);

        final newcomer = Identity.generate('Newcomer');
        server.addKey('kn', newcomer);
        final newcomerKey = UnlockedKey(keyId: 'kn', identity: newcomer);
        expect(await service.get(1, newcomerKey), isNull);
        expect(await service.onboardMissing(managerKey), 1);
        expect(await service.get(1, newcomerKey), companyKey);
        expect(await service.onboardMissing(managerKey), 0);

        expect(await service.createOrRotateCompanyKey(managerKey), 2);
        expect(await service.get(2, memberKey), isNot(equals(companyKey)));
      },
    );
  });
}
