import 'package:flutter/foundation.dart';

/// Typed failure of key management; [message] is safe to show to the user.
class KeyException implements Exception {
  const KeyException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Too many wrong passwords: try again after [remaining].
class KeyLockedException extends KeyException {
  KeyLockedException(this.remaining)
    : super('Too many wrong passwords. Try again in ${_fmt(remaining)}.');
  final Duration remaining;

  static String _fmt(Duration d) => d.inHours >= 1
      ? '${d.inHours} h ${d.inMinutes % 60} min'
      : d.inMinutes >= 1
      ? '${d.inMinutes} min ${d.inSeconds % 60} s'
      : '${d.inSeconds + 1} s';
}

/// A public key row from the server (`KeyOut`).
@immutable
class UserKeyInfo {
  const UserKeyInfo({
    required this.id,
    required this.userId,
    required this.deviceName,
    required this.fingerprint,
    required this.status,
    required this.signPub,
    required this.encPub,
  });

  final String id;
  final int userId;
  final String deviceName;
  final String fingerprint;

  /// `pending`, `active` or `retired`.
  final String status;
  final Map<String, dynamic> signPub;
  final Map<String, dynamic> encPub;

  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';
  bool get isRetired => status == 'retired';

  factory UserKeyInfo.fromJson(Map<String, dynamic> j) => UserKeyInfo(
    id: j['id'] as String,
    userId: j['user_id'] as int,
    deviceName: j['device_name'] as String,
    fingerprint: j['fingerprint'] as String,
    status: j['status'] as String,
    signPub: Map<String, dynamic>.from(j['sign_pub'] as Map),
    encPub: Map<String, dynamic>.from(j['enc_pub'] as Map),
  );
}

/// An active colleague and their active public keys (`GET /keys/directory`).
@immutable
class DirectoryUser {
  const DirectoryUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.keys,
  });

  final int id;
  final String email;
  final String fullName;
  final List<UserKeyInfo> keys;

  factory DirectoryUser.fromJson(Map<String, dynamic> j) => DirectoryUser(
    id: j['id'] as int,
    email: j['email'] as String,
    fullName: j['full_name'] as String,
    keys: [
      for (final k in j['keys'] as List)
        UserKeyInfo.fromJson(k as Map<String, dynamic>),
    ],
  );
}

/// A company-key wrap addressed to one of the caller's keys.
@immutable
class CompanyWrap {
  const CompanyWrap({
    required this.version,
    required this.keyId,
    required this.wrap,
  });
  final int version;
  final String keyId;
  final Map<String, dynamic> wrap;
}
