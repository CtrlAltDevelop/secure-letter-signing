import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// One storage config for the whole app. On macOS the data-protection keychain needs a signing team and a
/// keychain-access-groups entitlement, which a plain `flutter run` build does not have, so use the login keychain.
const appSecureStorage = FlutterSecureStorage(
  mOptions: MacOsOptions(usesDataProtectionKeychain: false),
);
