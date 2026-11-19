import 'package:http/http.dart' as http;
import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/security/security_api.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

import '../letters/fakes.dart';

Map<String, dynamic> userJson({
  bool guest = false,
  String? expires,
  bool manager = false,
  bool twoFactor = false,
}) => {
  'id': 2,
  'email': 'me@x.test',
  'full_name': 'Me',
  'title': '',
  'department': '',
  'department_id': null,
  'is_manager': manager,
  'is_active': true,
  'has_signing_pin': true,
  'permissions': ['user'],
  'is_guest': guest,
  'guest_expires_at': expires,
  'two_factor_enabled': twoFactor,
};

Map<String, dynamic> eventJson(
  int id, {
  bool success = true,
  String reason = '',
  String ip = '10.0.0.1',
  String device = 'macos',
}) => {
  'id': id,
  'at': '2026-03-21T08:30:00Z',
  'ip': ip,
  'user_agent': 'UA',
  'device_name': device,
  'success': success,
  'reason': reason,
};

/// A scripted server for the security endpoints; every call and body is recorded.
class FakeSecurityServer {
  Map<String, dynamic> twoFactor = {
    'enabled': false,
    'setup_pending': false,
    'recovery_codes_left': 0,
    'required': false,
  };
  List<Map<String, dynamic>> history = [
    eventJson(1),
    eventJson(2, success: false, reason: 'bad_password', ip: '1.2.3.4'),
  ];
  List<Map<String, dynamic>> guests = [];
  Map<String, dynamic> access = {
    'projects': [
      {'id': 'p1', 'role': 'member', 'active': true, 'name': 'Alpha', 'kind': ''},
    ],
    'customers': [],
    'conversations': [],
  };
  final List<Map<String, dynamic>> projectList = [
    {'id': 'p1', 'name': 'Alpha'},
    {'id': 'p2', 'name': 'Beta'},
  ];
  int wrongCodes = 0;
  bool guestMe = false;
  bool managerMe = false;
  String? guestExpires;
  List<Map<String, Object>> modules = [
    {'code': 'tasks', 'enabled': true},
    {'code': 'projects', 'enabled': true},
    {'code': 'chat', 'enabled': true},
  ];
  final calls = <http.Request>[];
  final bodies = <Object?>[];

  Object? lastBody(String method, String part) {
    for (var i = calls.length - 1; i >= 0; i--) {
      if (calls[i].method == method && calls[i].url.path.contains(part)) {
        return bodies[i];
      }
    }
    return null;
  }

  bool called(String method, String part) =>
      calls.any((r) => r.method == method && r.url.path.contains(part));

  http.Response handle(http.Request req, Object? body) {
    calls.add(req);
    bodies.add(body);
    final path = req.url.path.replaceFirst('/api', '');
    final m = req.method;
    if (path == '/auth/refresh') return json({'access': 'a', 'refresh': 'r2'});
    if (path == '/me') return json(userJson(guest: guestMe, expires: guestExpires, manager: managerMe));
    if (path == '/me/modules') return json({'plan': 'pro', 'modules': modules});
    if (path == '/auth/login' && m == 'POST') {
      return json({'two_factor_required': true, 'challenge': 'CH1'});
    }
    if (path == '/auth/login/2fa') {
      final b = body as Map;
      if (b['code'] == '000000') {
        wrongCodes++;
        return json({'detail': 'The code is wrong'}, 401);
      }
      return json({
        'access': 'a',
        'refresh': 'r',
        'session_id': 'S1',
        'user': userJson(twoFactor: true),
      });
    }
    if (path == '/me/2fa' && m == 'GET') return json(twoFactor);
    if (path == '/me/2fa' && m == 'POST') {
      return json({'secret': 'JBSWY3DPEHPK3PXP', 'otpauth_uri': 'otpauth://totp/Co:me?secret=JBSWY3DPEHPK3PXP'});
    }
    if (path == '/me/2fa/confirm') {
      twoFactor = {...twoFactor, 'enabled': true, 'recovery_codes_left': 10};
      return json({'recovery_codes': [for (var i = 0; i < 10; i++) 'rc-code-$i']});
    }
    if (path == '/me/2fa/disable') {
      twoFactor = {...twoFactor, 'enabled': false, 'recovery_codes_left': 0};
      return json({'detail': 'off'});
    }
    if (path == '/me/2fa/recovery-codes') {
      return json({'recovery_codes': [for (var i = 0; i < 10; i++) 'new-code-$i']});
    }
    if (path == '/me/login-history') return json(history);
    if (path.startsWith('/manage/users/') && path.endsWith('/login-history')) return json(history);
    if (path == '/me/sessions/revoke-others') return json({'detail': 'ok', 'revoked': 2});
    if (path == '/me/sessions') {
      return json([
        {'id': 'S1', 'device_name': 'this', 'platform': 'macos', 'ip': '', 'created_at': '2026-01-01T00:00:00Z', 'last_active': '2026-01-01T00:00:00Z', 'current': true, 'biometric': false},
        {'id': 'S2', 'device_name': 'phone', 'platform': 'android', 'ip': '', 'created_at': '2026-01-01T00:00:00Z', 'last_active': '2026-01-01T00:00:00Z', 'current': false, 'biometric': false},
      ]);
    }
    if (path == '/manage/guests' && m == 'GET') return json(guests);
    if (path == '/manage/guests' && m == 'POST') {
      final g = {
        ...userJson(guest: true),
        'id': 9,
        'email': (body as Map)['email'],
        'full_name': body['full_name'],
        'guest_expires_at': body['guest_expires_at'],
      };
      guests = [...guests, g];
      return json(g);
    }
    if (path.startsWith('/manage/guests/') && m == 'PATCH') return json(guests.first);
    if (path.endsWith('/active')) return json(guests.first);
    if (path == '/manage/invites') return json({'id': 1, 'code': 'GUEST-CODE-1', 'guest': true});
    if (path.endsWith('/access') && m == 'GET') return json(access);
    if (path.endsWith('/access') && m == 'PUT') {
      final rows = (body as Map)['projects'] as List;
      final next = [
        for (final r in (access['projects'] as List))
          rows.any((x) => (x as Map)['id'] == (r as Map)['id'])
              ? {...r, ...(rows.firstWhere((x) => (x as Map)['id'] == r['id']) as Map)}
              : r,
        for (final r in rows)
          if (!(access['projects'] as List).any((x) => (x as Map)['id'] == (r as Map)['id']))
            {...r as Map, 'name': 'Beta'},
      ];
      access = {...access, 'projects': next};
      return json(access);
    }
    if (path == '/projects') return json(projectList);
    if (path == '/customers' || path == '/chat/conversations') return json(<Object>[]);
    return json({'detail': 'unhandled $m $path'}, 404);
  }
}

({FakeSecurityServer server, AuthController auth, SecurityApi api}) fakeSecurity() {
  final server = FakeSecurityServer();
  final f = fakeApi(server.handle);
  final auth = AuthController(f.client, biometrics: FakeBiometrics());
  return (server: server, auth: auth, api: SecurityApi(WorkspaceApi(f.client)));
}
