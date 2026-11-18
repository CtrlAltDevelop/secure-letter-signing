import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/crypto/crypto_primitives.dart';
import 'package:letter_signing/crypto/document_crypto.dart';
import 'package:letter_signing/crypto/identity.dart';

const _password = 'Dart-Pass#2026x';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  final v = _json('../test-vectors/v2.json');

  test('strongKeyPassword enforces length and character classes', () {
    expect(strongKeyPassword('Abcdef1!gh'), isTrue);
    expect(strongKeyPassword('Abcdef1!g'), isFalse);
    expect(strongKeyPassword('abcdef1!ghij'), isFalse);
    expect(strongKeyPassword('ABCDEF1!GHIJ'), isFalse);
    expect(strongKeyPassword('Abcdefgh!ij'), isFalse);
    expect(strongKeyPassword('Abcdefgh1ij'), isFalse);
  });

  test('unwraps the JS key file, wraps, decrypts body (JS vectors)', () async {
    final id = await Identity.unwrap(v['keyFile'] as Map<String, dynamic>, v['password'] as String);
    expect(id.fp, v['fp']);
    final docKey = unwrapDocKey(v['wrapped'] as Map<String, dynamic>, id.encJwk, id.fp);
    expect(base64.encode(docKey), v['docKey']);
    expect(decryptJson(v['body'] as Map<String, dynamic>, docKey), v['bodyPlain']);
    expect(
      () => unwrapDocKey(v['wrapped'] as Map<String, dynamic>, id.encJwk, 'other-fp'),
      throwsA(isA<DecryptionException>()),
    );
  });

  test('wrong password throws WrongPasswordException', () async {
    expect(
      Identity.unwrap(v['keyFile'] as Map<String, dynamic>, 'nope'),
      throwsA(isA<WrongPasswordException>()),
    );
  });

  test('Dart identity round-trips and is written for the JS side', () async {
    final id = Identity.generate('Dart User');
    final keyFile = await id.wrap(_password);
    final back = await Identity.unwrap(keyFile, _password);
    expect(back.fp, id.fp);
    expect(keyFile['kdf']['iter'], kdfIterations);

    final docKey = newDocKey();
    final wrapped = wrapDocKey(docKey, id.publicFile['enc'] as Map<String, dynamic>, id.fp);
    expect(unwrapDocKey(wrapped, back.encJwk, back.fp), docKey);
    final tampered = {...wrapped, 'ct': base64.encode(Uint8List(48))};
    expect(() => unwrapDocKey(tampered, back.encJwk, back.fp), throwsA(isA<DecryptionException>()));

    final plain = {'subject': 'Dart é中', 'list': [1, 2]};
    final box = encryptJson(plain, docKey);
    expect(decryptJson(box, docKey), plain);
    expect(() => decryptJson(box, newDocKey()), throwsA(isA<DecryptionException>()));

    final payload = {'v': 1, 'note': 'dart', 'signer': {'name': 'Dart User', 'fp': id.fp}};
    final sig = signPayload(payload, back.signJwk);
    expect(verifyPayload(payload, sig, id.publicFile['sign'] as Map<String, dynamic>), isTrue);
    expect(() => signPayload({'x': 1.5}, back.signJwk), throwsFormatException);

    File('../test-vectors/dart-e2e.json').writeAsStringSync(jsonEncode({
      'password': _password,
      'keyFile': keyFile,
      'pub': id.publicFile,
      'docKey': base64.encode(docKey),
      'wrapped': wrapped,
      'plain': plain,
      'body': box,
      'payload': payload,
      'sig': sig,
    }));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
