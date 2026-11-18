import 'package:flutter/foundation.dart';

import 'api_client.dart';

@immutable
class UserInfo {
  const UserInfo({
    required this.id,
    required this.email,
    required this.fullName,
    required this.title,
    required this.department,
    required this.isManager,
    required this.permissions,
    this.isActive = true,
  });

  final int id;
  final String email;
  final String fullName;
  final String title;
  final String department;
  final bool isManager;
  final bool isActive;
  final List<String> permissions;

  factory UserInfo.fromJson(Map<String, dynamic> j) => UserInfo(
    id: j['id'] as int,
    email: j['email'] as String,
    fullName: j['full_name'] as String,
    title: j['title'] as String,
    department: j['department'] as String,
    isManager: j['is_manager'] as bool,
    isActive: j['is_active'] as bool,
    permissions: List<String>.from(j['permissions'] as List),
  );
}

enum SignupResult { registered, verifyEmail }

/// Holds who is signed in; screens listen to it.
class AuthController extends ChangeNotifier {
  AuthController(this.api) {
    api.onSessionLost = () {
      _user = null;
      notifyListeners();
    };
  }

  final ApiClient api;
  UserInfo? _user;
  UserInfo? get user => _user;
  String? sessionId; // from the login response; null after an app restart (decoded from the token instead)

  Future<void> restore() async {
    if (await api.restore()) {
      _user = UserInfo.fromJson(
        await api.call('GET', '/me') as Map<String, dynamic>,
      );
      notifyListeners();
    }
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
    _user = UserInfo.fromJson(data['user'] as Map<String, dynamic>);
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

  Future<void> updateProfile({
    String? fullName,
    String? title,
    String? department,
  }) async {
    final data = await api.call(
      'PATCH',
      '/me',
      body: {
        'full_name': ?fullName,
        'title': ?title,
        'department': ?department,
      },
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
      notifyListeners();
    }
  }
}
