import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';

/// Local biometric check. A failed or cancelled check returns false, never throws.
abstract interface class Biometrics {
  Future<bool> available();
  Future<bool> authenticate(String reason);
}

class LocalAuthBiometrics implements Biometrics {
  const LocalAuthBiometrics();

  @override
  Future<bool> available() async {
    // No platform authenticator behind local_auth on web.
    if (kIsWeb) {
      return false;
    }
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
    if (kIsWeb) {
      return false;
    }
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
