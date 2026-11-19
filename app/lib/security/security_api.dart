import 'package:letter_signing/security/security_models.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// Typed access to two-step login, login history, session cleanup and the manager's guest /
/// access tools. 403/404/409 come back as the typed exceptions of [WorkspaceApi].
class SecurityApi {
  SecurityApi(this.workspace);

  final WorkspaceApi workspace;

  Future<TwoFactorStatus> status() async =>
      TwoFactorStatus.fromJson(asMap(await workspace.call('GET', '/me/2fa')));

  Future<TwoFactorSetup> startSetup() async =>
      TwoFactorSetup.fromJson(asMap(await workspace.call('POST', '/me/2fa')));

  /// Turns 2FA on; the returned recovery codes are shown once.
  Future<List<String>> confirm(String code) async => _codes(
    await workspace.call('POST', '/me/2fa/confirm', body: {'code': code}),
  );

  Future<void> disable({
    required String password,
    String? code,
    String? recoveryCode,
  }) => workspace.call(
    'POST',
    '/me/2fa/disable',
    body: _proof(password, code, recoveryCode),
  );

  Future<List<String>> newRecoveryCodes({
    required String password,
    String? code,
    String? recoveryCode,
  }) async => _codes(
    await workspace.call(
      'POST',
      '/me/2fa/recovery-codes',
      body: _proof(password, code, recoveryCode),
    ),
  );

  static Map<String, Object?> _proof(
    String password,
    String? code,
    String? recovery,
  ) => {
    'password': password,
    if (code != null && code.isNotEmpty) 'code': code,
    if (recovery != null && recovery.isNotEmpty) 'recovery_code': recovery,
  };

  static List<String> _codes(Object? data) => [
    for (final c in (asMap(data)['recovery_codes'] as List? ?? const [])) '$c',
  ];

  Future<List<LoginEvent>> myLoginHistory({int limit = 100, int offset = 0}) =>
      _history('/me/login-history', limit, offset);

  Future<List<LoginEvent>> userLoginHistory(
    int userId, {
    int limit = 100,
    int offset = 0,
  }) => _history('/manage/users/$userId/login-history', limit, offset);

  Future<List<LoginEvent>> _history(String path, int limit, int offset) async =>
      [
        for (final j in asMapList(
          await workspace.call(
            'GET',
            '$path${WorkspaceApi.query({'limit': limit, 'offset': offset})}',
          ),
        ))
          LoginEvent.fromJson(j),
      ];

  /// Closes every session but this device's; returns how many were closed.
  Future<int> revokeOtherSessions() async =>
      (asMap(
                await workspace.call('POST', '/me/sessions/revoke-others'),
              )['revoked']
              as num?)
          ?.toInt() ??
      0;

  // ---- manager ----

  Future<List<GuestUser>> guests() async => [
    for (final j in asMapList(await workspace.call('GET', '/manage/guests')))
      GuestUser.fromJson(j),
  ];

  Future<GuestUser> createGuest({
    required String email,
    required String password,
    String fullName = '',
    DateTime? expiresAt,
  }) async => GuestUser.fromJson(
    asMap(
      await workspace.call(
        'POST',
        '/manage/guests',
        body: {
          'email': email,
          'password': password,
          'full_name': fullName,
          if (expiresAt != null)
            'guest_expires_at': expiresAt.toUtc().toIso8601String(),
        },
      ),
    ),
  );

  /// [expiresAt] null with [clearExpiry] false leaves the expiry as it is.
  Future<GuestUser> updateGuest(
    int id, {
    DateTime? expiresAt,
    bool clearExpiry = false,
  }) async => GuestUser.fromJson(
    asMap(
      await workspace.call(
        'PATCH',
        '/manage/guests/$id',
        body: {
          if (expiresAt != null)
            'guest_expires_at': expiresAt.toUtc().toIso8601String(),
          if (clearExpiry) 'clear_expiry': true,
        },
      ),
    ),
  );

  /// Switching a guest off is the ordinary user deactivation.
  Future<void> setActive(int userId, {required bool active}) => workspace.call(
    'POST',
    '/manage/users/$userId/active',
    body: {'active': active},
  );

  /// A signup invitation for guests (`guest: true`, optional expiry of the account).
  Future<Map<String, dynamic>> createGuestInvite({
    int? maxUses = 1,
    DateTime? guestExpiresAt,
  }) async => asMap(
    await workspace.call(
      'POST',
      '/manage/invites',
      body: {
        'max_uses': maxUses,
        'guest': true,
        'codes': const <String>[],
        if (guestExpiresAt != null)
          'guest_expires_at': guestExpiresAt.toUtc().toIso8601String(),
      },
    ),
  );

  Future<UserAccess> access(int userId) async => UserAccess.fromJson(
    asMap(await workspace.call('GET', '/manage/users/$userId/access')),
  );

  /// Listed rows are created, switched on/off or re-roled; the rest stay as they are.
  Future<UserAccess> saveAccess(
    int userId, {
    List<AccessRow> projects = const [],
    List<AccessRow> customers = const [],
    List<AccessRow> conversations = const [],
  }) async => UserAccess.fromJson(
    asMap(
      await workspace.call(
        'PUT',
        '/manage/users/$userId/access',
        body: {
          'projects': [for (final r in projects) r.toWire()],
          'customers': [for (final r in customers) r.toWire()],
          'conversations': [for (final r in conversations) r.toWire()],
        },
      ),
    ),
  );

  /// Things a manager can add to a user: `(id, name)` per kind; a kind that fails to load is empty.
  Future<AccessCandidates> candidates() async {
    Future<List<(String, String)>> pairs(
      String path, {
      bool Function(Map<String, dynamic>)? where,
    }) async {
      try {
        return [
          for (final j in asMapList(await workspace.call('GET', path)))
            if (where == null || where(j))
              (asString(j['id']), asString(j['name'])),
        ];
      } on Object {
        return const [];
      }
    }

    final results = await Future.wait([
      pairs('/projects'),
      pairs('/customers'),
      pairs(
        '/chat/conversations',
        where: (j) =>
            (j['kind'] == 'group' || j['kind'] == 'channel') &&
            j['project_id'] == null &&
            j['customer_id'] == null,
      ),
    ]);
    return AccessCandidates(
      projects: results[0],
      customers: results[1],
      conversations: results[2],
    );
  }
}

/// `(id, name)` pairs a manager can add to a user, per kind.
class AccessCandidates {
  const AccessCandidates({
    this.projects = const [],
    this.customers = const [],
    this.conversations = const [],
  });
  final List<(String, String)> projects;
  final List<(String, String)> customers;
  final List<(String, String)> conversations;
}
