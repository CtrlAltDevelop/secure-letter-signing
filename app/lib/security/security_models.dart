import 'package:flutter/foundation.dart';

import 'package:letter_signing/workspace/models.dart';

/// `GET /me/2fa`.
@immutable
class TwoFactorStatus {
  const TwoFactorStatus({
    required this.enabled,
    required this.setupPending,
    required this.recoveryCodesLeft,
    required this.required,
  });

  final bool enabled;
  final bool setupPending;
  final int recoveryCodesLeft;

  /// The company requires two-step login.
  final bool required;

  factory TwoFactorStatus.fromJson(Map<String, dynamic> j) => TwoFactorStatus(
    enabled: j['enabled'] == true,
    setupPending: j['setup_pending'] == true,
    recoveryCodesLeft: (j['recovery_codes_left'] as num?)?.toInt() ?? 0,
    required: j['required'] == true,
  );
}

/// `POST /me/2fa`: the pending secret and the otpauth URI (no QR package: shown as text).
@immutable
class TwoFactorSetup {
  const TwoFactorSetup({required this.secret, required this.otpauthUri});
  final String secret;
  final String otpauthUri;

  factory TwoFactorSetup.fromJson(Map<String, dynamic> j) => TwoFactorSetup(
    secret: asString(j['secret']),
    otpauthUri: asString(j['otpauth_uri']),
  );
}

/// One sign-in or failed attempt of `GET /me/login-history`.
@immutable
class LoginEvent {
  const LoginEvent({
    required this.id,
    required this.at,
    required this.ip,
    required this.userAgent,
    required this.deviceName,
    required this.success,
    required this.reason,
  });

  final int id;
  final DateTime at;
  final String ip;
  final String userAgent;
  final String deviceName;
  final bool success;

  /// Empty on success; `bad_password`, `bad_code`, `locked`, `guest_expired`.
  final String reason;

  String get device => deviceName.isNotEmpty ? deviceName : userAgent;

  factory LoginEvent.fromJson(Map<String, dynamic> j) => LoginEvent(
    id: (j['id'] as num).toInt(),
    at: DateTime.parse(j['at'] as String),
    ip: asString(j['ip']),
    userAgent: asString(j['user_agent']),
    deviceName: asString(j['device_name']),
    success: j['success'] == true,
    reason: asString(j['reason']),
  );
}

/// One membership row of `GET /manage/users/{id}/access`.
@immutable
class AccessRow {
  const AccessRow({
    required this.id,
    required this.role,
    required this.active,
    this.name = '',
    this.kind = '',
  });

  final String id;
  final String role;
  final bool active;
  final String name;
  final String kind;

  AccessRow copyWith({String? role, bool? active}) => AccessRow(
    id: id,
    role: role ?? this.role,
    active: active ?? this.active,
    name: name,
    kind: kind,
  );

  factory AccessRow.fromJson(Map<String, dynamic> j) => AccessRow(
    id: asString(j['id']),
    role: asString(j['role']),
    active: j['active'] != false,
    name: asString(j['name']),
    kind: asString(j['kind']),
  );

  Map<String, Object?> toWire() => {'id': id, 'active': active, 'role': role};
}

@immutable
class UserAccess {
  const UserAccess({
    this.projects = const [],
    this.customers = const [],
    this.conversations = const [],
  });

  final List<AccessRow> projects;
  final List<AccessRow> customers;
  final List<AccessRow> conversations;

  factory UserAccess.fromJson(Map<String, dynamic> j) {
    List<AccessRow> rows(String key) => [
      for (final r in asMapList(j[key])) AccessRow.fromJson(r),
    ];
    return UserAccess(
      projects: rows('projects'),
      customers: rows('customers'),
      conversations: rows('conversations'),
    );
  }
}

/// A guest account of `GET /manage/guests` (a `UserOut`).
@immutable
class GuestUser {
  const GuestUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isActive,
    this.expiresAt,
  });

  final int id;
  final String email;
  final String fullName;
  final bool isActive;
  final DateTime? expiresAt;

  bool get expired => expiresAt != null && !expiresAt!.isAfter(DateTime.now());

  factory GuestUser.fromJson(Map<String, dynamic> j) => GuestUser(
    id: (j['id'] as num).toInt(),
    email: asString(j['email']),
    fullName: asString(j['full_name']),
    isActive: j['is_active'] != false,
    expiresAt: j['guest_expires_at'] == null
        ? null
        : DateTime.parse(j['guest_expires_at'] as String),
  );
}
