import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'crypto_primitives.dart';
import 'letter_crypto.dart';

const kdfIterations = 600000;
const _formatVersion = 1;

/// True when [password] has >=10 chars with upper, lower, digit and symbol.
bool strongKeyPassword(String password) =>
    password.length >= 10 &&
    RegExp('[A-Z]').hasMatch(password) &&
    RegExp('[a-z]').hasMatch(password) &&
    RegExp('[0-9]').hasMatch(password) &&
    RegExp(r'[^A-Za-z0-9]').hasMatch(password);

/// A user identity: ECDSA (sign) + ECDH (enc) P-256 key pairs. Treat as immutable.
class Identity {
  const Identity({
    required this.name,
    required this.signJwk,
    required this.encJwk,
  });

  final String name;

  /// Private JWKs (include `d`).
  final Map<String, dynamic> signJwk;
  final Map<String, dynamic> encJwk;

  factory Identity.generate(String name) => Identity(
    name: name,
    signJwk: generateP256Jwk().priv,
    encJwk: generateP256Jwk().priv,
  );

  static Map<String, dynamic> _public(Map<String, dynamic> j) => {
    for (final k in const ['kty', 'crv', 'x', 'y']) k: j[k],
  };

  /// Public file `{v,name,sign,enc}` (what gets shared / registered).
  Map<String, dynamic> get publicFile => {
    'v': _formatVersion,
    'name': name,
    'sign': _public(signJwk),
    'enc': _public(encJwk),
  };

  String get fp => fingerprint(publicFile);

  /// JS-compatible key file; PBKDF2 runs in a background isolate.
  Future<Map<String, dynamic>> wrap(String password) async {
    final salt = randomBytes(16);
    final iv = randomBytes(12);
    final privCanon = canonicalJson({'sign': signJwk, 'enc': encJwk});
    final ct = await Isolate.run(() {
      final key = pbkdf2(password, salt, kdfIterations);
      return aesGcm(true, key, iv, utf8Bytes(privCanon));
    });
    return {
      'v': _formatVersion,
      'type': 'key',
      'name': name,
      'pub': {...publicFile, 'fp': fp},
      'kdf': {'salt': base64.encode(salt), 'iter': kdfIterations},
      'iv': base64.encode(iv),
      'ct': base64.encode(ct),
    };
  }

  /// Throws [WrongPasswordException] on a bad password, [CryptoException] on a malformed file.
  static Future<Identity> unwrap(
    Map<String, dynamic> keyFile,
    String password,
  ) async {
    final Uint8List salt, iv, ct;
    final int iter;
    try {
      if (keyFile['v'] != _formatVersion || keyFile['type'] != 'key')
        throw const FormatException();
      final kdf = keyFile['kdf'] as Map<String, dynamic>;
      salt = base64.decode(kdf['salt'] as String);
      iter = kdf['iter'] as int;
      iv = base64.decode(keyFile['iv'] as String);
      ct = base64.decode(keyFile['ct'] as String);
      if (iter < 1) throw const FormatException();
    } on Object {
      throw const CryptoException('Invalid key file');
    }
    final Uint8List plain;
    try {
      plain = await Isolate.run(
        () => aesGcm(false, pbkdf2(password, salt, iter), iv, ct),
      );
    } on DecryptionException {
      throw const WrongPasswordException();
    }
    final priv = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    return Identity(
      name: keyFile['name'] as String,
      signJwk: priv['sign'] as Map<String, dynamic>,
      encJwk: priv['enc'] as Map<String, dynamic>,
    );
  }
}
