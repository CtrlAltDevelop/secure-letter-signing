import 'package:letter_signing/api/secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Minimal string key-value store (OS secure store in production, memory in tests).
abstract interface class SecureKv {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureKv implements SecureKv {
  const FlutterSecureKv();
  static const _storage = appSecureStorage;
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class MemoryKv implements SecureKv {
  final Map<String, String> data = {};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<void> delete(String key) async => data.remove(key);
}

/// Namespaces another store, so several accounts on one device never see each other's keys.
class PrefixedKv implements SecureKv {
  const PrefixedKv(this._inner, this.prefix);
  final SecureKv _inner;
  final String prefix;
  @override
  Future<String?> read(String key) => _inner.read('$prefix$key');
  @override
  Future<void> write(String key, String value) =>
      _inner.write('$prefix$key', value);
  @override
  Future<void> delete(String key) => _inner.delete('$prefix$key');
}

/// Local biometric check. A failed or cancelled check returns false, never throws.
abstract interface class Biometrics {
  Future<bool> available();
  Future<bool> authenticate(String reason);
}

class LocalAuthBiometrics implements Biometrics {
  const LocalAuthBiometrics();

  @override
  Future<bool> available() async {
    try {
      final auth = LocalAuthentication();
      return await auth.isDeviceSupported() &&
          (await auth.getAvailableBiometrics()).isNotEmpty;
    } on Object {
      return false; // unsupported platform (e.g. Windows without Hello) or plugin error
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await LocalAuthentication().authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } on Object {
      return false;
    }
  }
}
