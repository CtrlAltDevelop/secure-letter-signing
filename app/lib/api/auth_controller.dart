import 'package:flutter/foundation.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/auth/biometrics.dart';

@immutable
class UserInfo {
  const UserInfo({
    required this.id,
    required this.email,
    required this.fullName,
    required this.title,
    required this.department,
    required this.isManager,
    this.departmentId,
    required this.permissions,
    this.isActive = true,
    this.hasSigningPin = true,
  });

  final int id;
  final String email;
  final String fullName;
  final String title;
  final String department;
  final int? departmentId;
  final bool isManager;
  final bool isActive;
  final bool hasSigningPin;
  final List<String> permissions;

  UserInfo withSigningPin() => UserInfo(
    id: id,
    email: email,
    fullName: fullName,
    title: title,
    department: department,
    departmentId: departmentId,
    isManager: isManager,
    isActive: isActive,
    hasSigningPin: true,
    permissions: permissions,
  );

  factory UserInfo.fromJson(Map<String, dynamic> j) => UserInfo(
    id: j['id'] as int,
    email: j['email'] as String,
    fullName: j['full_name'] as String,
    title: j['title'] as String,
    department: j['department'] as String,
    departmentId: j['department_id'] as int?,
    isManager: j['is_manager'] as bool,
    isActive: j['is_active'] as bool,
    hasSigningPin: (j['has_signing_pin'] as bool?) ?? false,
    permissions: List<String>.from(j['permissions'] as List),
  );
}

/// Enrolling fingerprint/face was refused: 403 wrong PIN, 409 no PIN set, 429 locked.
class BiometricEnrolError implements Exception {
  const BiometricEnrolError(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

enum SignupResult { registered, verifyEmail }

/// Holds who is signed in; screens listen to it.
class AuthController extends ChangeNotifier {
  AuthController(this.api, {this.biometrics = const LocalAuthBiometrics()}) {
    api.onSessionLost = () {
      _user = null;
      notifyListeners();
    };
  }

  final ApiClient api;
  final Biometrics biometrics;
  UserInfo? _user;
  UserInfo? get user => _user;

  /// This device's session id (login response or `GET /me/sessions`).
  String? sessionId;

  /// Whether the server flags this session as biometric (enrolled with the PIN).
  bool sessionBiometric = false;

  /// Whether this device has fingerprint/face set up.
  bool biometricAvailable = false;

  bool _sessionKnown = false;
  bool _enrolmentDismissed = false;

  /// True when this device could enrol fingerprint/face but the session is not flagged yet.
  bool get canEnrollBiometric =>
      _sessionKnown && biometricAvailable && !sessionBiometric;

  /// Whether to offer enrolment now: [canEnrollBiometric] until enrolled or dismissed for this app run.
  bool get needsBiometricEnrolment =>
      canEnrollBiometric && !_enrolmentDismissed;

  /// "Not now": stop offering enrolment until the app restarts.
  void dismissBiometricEnrolment() {
    if (_enrolmentDismissed) return;
    _enrolmentDismissed = true;
    notifyListeners();
  }

  Future<void> restore() async {
    if (!await api.restore()) return;
    _user = UserInfo.fromJson(
      await api.call('GET', '/me') as Map<String, dynamic>,
    );
    notifyListeners();
    await syncSession();
  }

  /// Works out this device's biometric state from the server's session flag and
  /// local availability. Best effort: offline or a server error never blocks the app.
  Future<void> syncSession() async {
    try {
      biometricAvailable = await biometrics.available();
      final current = await _currentSession();
      if (current == null) return;
      sessionId = '${current['id'] ?? sessionId}';
      sessionBiometric = current['biometric'] == true;
      if (!biometricAvailable && sessionBiometric) {
        final data = await api.call(
          'PATCH',
          '/me/sessions/current',
          body: {'biometric': false},
        );
        sessionBiometric = data is Map && data['biometric'] == true;
      }
      _sessionKnown = true;
      notifyListeners();
    } on Exception {
      // Keep the values we have; enrolment stays hidden until the state is known.
    }
  }

  Future<Map<dynamic, dynamic>?> _currentSession() async {
    final rows = await api.call('GET', '/me/sessions');
    if (rows is! List) return null;
    for (final row in rows) {
      if (row is Map && row['current'] == true) return row;
    }
    return null;
  }

  /// Confirms fingerprint/face locally, then enrols this session with the PIN
  /// (`PATCH /me/sessions/current`). Returns false when the local check was
  /// cancelled (nothing is sent). Throws [BiometricEnrolError] for a wrong PIN,
  /// no PIN or too many attempts.
  Future<bool> enrollBiometric(String pin) async {
    final ok = await biometrics.authenticate(
      'Enable fingerprint / face on this device',
    );
    if (!ok) return false;
    try {
      final data = await api.call(
        'PATCH',
        '/me/sessions/current',
        body: {'biometric': true, 'pin': pin},
      );
      if (data is Map) sessionId = '${data['id'] ?? sessionId}';
      sessionBiometric = data is! Map || data['biometric'] != false;
    } on ApiException catch (e) {
      if (e.status == 403 || e.status == 409 || e.status == 429) {
        throw BiometricEnrolError(e.status, e.message);
      }
      rethrow;
    }
    notifyListeners();
    return true;
  }

  /// Sets or changes the 6-digit signing PIN (`PUT /me/signing-pin`).
  Future<void> setSigningPin(String pin, String password) async {
    await api.call(
      'PUT',
      '/me/signing-pin',
      body: {'pin': pin, 'password': password},
    );
    _user = _user?.withSigningPin();
    notifyListeners();
  }

  Future<void> login(
    String email,
    String password, {
    String deviceName = '',
    String platform = '',
  }) async {
    final data = await api.call(
      'POST',
      '/auth/login',
      auth: false,
      body: {
        'email': email,
        'password': password,
        'device_name': deviceName,
        'platform': platform,
      },
    ) as Map<String, dynamic>;
    api.setSession(
      access: data['access'] as String,
      refresh: data['refresh'] as String,
    );
    sessionId = data['session_id'] as String?;
    // New sessions are never biometric; the server ignores any client claim.
    sessionBiometric = false;
    _sessionKnown = true;
    _enrolmentDismissed = false;
    _user = UserInfo.fromJson(data['user'] as Map<String, dynamic>);
    biometricAvailable = await biometrics.available();
    notifyListeners();
  }

  Future<SignupResult> signup({
    required String email,
    required String password,
    String fullName = '',
    String? inviteCode,
  }) async {
    // Both outcomes are 2xx; the body text differs but ApiClient hides the status, so ask again by intent:
    // an invite code means immediate activation, otherwise the user must verify by email.
    await api.call(
      'POST',
      '/auth/signup',
      auth: false,
      body: {
        'email': email,
        'password': password,
        'full_name': fullName,
        if (inviteCode != null && inviteCode.isNotEmpty)
          'invite_code': inviteCode,
      },
    );
    return inviteCode != null && inviteCode.isNotEmpty
        ? SignupResult.registered
        : SignupResult.verifyEmail;
  }

  Future<void> verifyEmail(String token) => api.call(
    'POST',
    '/auth/verify-email',
    auth: false,
    body: {'token': token},
  );

  Future<void> requestReset(String email) => api.call(
    'POST',
    '/auth/password-reset/request',
    auth: false,
    body: {'email': email},
  );

  Future<void> confirmReset(String token, String newPassword) => api.call(
    'POST',
    '/auth/password-reset/confirm',
    auth: false,
    body: {'token': token, 'new_password': newPassword},
  );

  Future<void> updateProfile({String? fullName, String? title}) async {
    final data = await api.call(
      'PATCH',
      '/me',
      body: {'full_name': ?fullName, 'title': ?title},
    ) as Map<String, dynamic>;
    _user = UserInfo.fromJson(data);
    notifyListeners();
  }

  Future<void> changePassword(String current, String next) => api.call(
    'POST',
    '/me/password',
    body: {'current_password': current, 'new_password': next},
  );

  Future<void> logout() async {
    try {
      await api.call('POST', '/auth/logout');
    } on ApiException {
      // Already invalid on the server; local sign-out still proceeds.
    } finally {
      await api.clearSession();
      _user = null;
      _sessionKnown = false;
      sessionBiometric = false;
      notifyListeners();
    }
  }
}
