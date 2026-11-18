import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/crypto/letter_crypto.dart';

Map<String, dynamic> _vectors() =>
    jsonDecode(File('../test-vectors/v1.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  final v = _vectors();
  final pub = v['pub'] as Map<String, dynamic>;
  final priv = v['priv'] as Map<String, dynamic>;

  test('fingerprint matches the JS implementation', () {
    expect(fingerprint(pub), v['fp']);
  });

  test('verifies a signature produced by JS', () {
    expect(verifySigned(v['signed'] as Map<String, dynamic>, pub), isTrue);
  });

  test('rejects a JS signature when the payload was edited', () {
    final signed = jsonDecode(jsonEncode(v['signed'])) as Map<String, dynamic>;
    (signed['payload'] as Map<String, dynamic>)['note'] = 'tampered';
    expect(verifySigned(signed, pub), isFalse);
  });

  test('decrypts a letter encrypted by JS', () {
    final letter = decryptLetter(v['letterFile'] as Map<String, dynamic>, priv['enc'] as Map<String, dynamic>, v['fp'] as String);
    expect(letter, v['letter']);
  });

  test('rejects a tampered ciphertext', () {
    final file = jsonDecode(jsonEncode(v['letterFile'])) as Map<String, dynamic>;
    final ct = base64.decode(file['ct'] as String);
    ct[0] ^= 1;
    file['ct'] = base64.encode(ct);
    expect(
      () => decryptLetter(file, priv['enc'] as Map<String, dynamic>, v['fp'] as String),
      throwsFormatException,
    );
  });

  test('canonical JSON sorts keys and rejects floats', () {
    expect(canonicalJson({'b': 1, 'a': [ {'z': 1, 'y': 2} ]}), '{"a":[{"y":2,"z":1}],"b":1}');
    expect(() => canonicalJson({'a': 1.5}), throwsFormatException);
  });

  test('Dart signature round-trips and is written for the JS verifier', () {
    final payload = {'v': 1, 'letter': v['letter'], 'decision': 'approved', 'note': 'dart', 'sigImage': '',
      'signedAt': '2026-01-01T00:00:00.000Z', 'signer': {'name': pub['name'], 'fp': v['fp']}};
    final sig = signBytes(Uint8List.fromList(utf8.encode(canonicalJson(payload))), priv['sign'] as Map<String, dynamic>);
    final signed = {'v': 1, 'type': 'signed', 'payload': payload, 'sig': base64.encode(sig)};
    expect(verifySigned(signed, pub), isTrue);
    File('../test-vectors/dart-signed.json').writeAsStringSync(jsonEncode(signed));
  });
}
