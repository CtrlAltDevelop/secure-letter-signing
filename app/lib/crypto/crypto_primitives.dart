import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'letter_crypto.dart';

/// Base class of every failure raised by the crypto layer.
class CryptoException implements Exception {
  const CryptoException(this.message);
  final String message;
  @override
  String toString() => '$runtimeType: $message';
}

/// Authentication failed: tampered data, wrong key or wrong AAD.
class DecryptionException extends CryptoException {
  const DecryptionException([super.message = 'Decryption failed']);
}

/// Key-file password did not decrypt the private keys.
class WrongPasswordException extends CryptoException {
  const WrongPasswordException()
    : super('Wrong password or corrupted key file');
}

final SecureRandom _rng = () {
  final r = SecureRandom('Fortuna');
  final seeder = Random.secure();
  r.seed(
    KeyParameter(
      Uint8List.fromList(List.generate(32, (_) => seeder.nextInt(256))),
    ),
  );
  return r;
}();

Uint8List randomBytes(int n) => _rng.nextBytes(n);

Uint8List utf8Bytes(String s) => Uint8List.fromList(utf8.encode(s));

/// AES-256-GCM with a 128-bit tag; output is ct||tag like WebCrypto.
Uint8List aesGcm(
  bool encrypt,
  Uint8List key,
  Uint8List iv,
  Uint8List data, [
  Uint8List? aad,
]) {
  final gcm = GCMBlockCipher(AESEngine())
    ..init(
      encrypt,
      AEADParameters(KeyParameter(key), 128, iv, aad ?? Uint8List(0)),
    );
  try {
    return gcm.process(data);
  } on InvalidCipherTextException {
    throw const DecryptionException();
  }
}

/// PBKDF2-HMAC-SHA256 -> 32 bytes.
Uint8List pbkdf2(String password, Uint8List salt, int iterations) {
  final kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(salt, iterations, 32));
  return kdf.process(utf8Bytes(password));
}

/// ECDH(priv, pub) -> HKDF-SHA256(empty salt, info 'letter-v1') -> 32-byte AES key.
Uint8List deriveAesKey(
  Map<String, dynamic> privJwk,
  Map<String, dynamic> pubJwk,
) {
  final agreement = ECDHBasicAgreement()..init(ecPrivateKey(privJwk));
  final shared = bigIntTo32(agreement.calculateAgreement(ecPublicKey(pubJwk)));
  final hkdf = HKDFKeyDerivator(SHA256Digest())
    ..init(HkdfParameters(shared, 32, Uint8List(0), utf8Bytes('letter-v1')));
  return hkdf.process(Uint8List(0));
}

/// Fresh P-256 key pair as JWKs: `pub` {kty,crv,x,y}, `priv` adds `d`.
({Map<String, dynamic> pub, Map<String, dynamic> priv}) generateP256Jwk() {
  final gen = ECKeyGenerator()
    ..init(ParametersWithRandom(ECKeyGeneratorParameters(p256Curve), _rng));
  final pair = gen.generateKeyPair();
  final q = pair.publicKey.Q!;
  final pub = <String, dynamic>{
    'kty': 'EC',
    'crv': 'P-256',
    'x': b64uEncode(bigIntTo32(q.x!.toBigInteger()!)),
    'y': b64uEncode(bigIntTo32(q.y!.toBigInteger()!)),
  };
  final d = b64uEncode(bigIntTo32(pair.privateKey.d!));
  return (pub: pub, priv: {...pub, 'd': d});
}
