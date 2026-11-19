import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/security/guests_card.dart';
import 'package:letter_signing/security/security_models.dart';
import 'package:letter_signing/security/user_access_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import '../letters/fakes.dart';
import 'security_fixtures.dart';

Map<String, dynamic> _guest({
  String? expires = '2099-01-01T00:00:00Z',
  bool active = true,
}) => {
  ...userJson(guest: true),
  'id': 9,
  'email': 'ext@x.test',
  'full_name': 'External',
  'guest_expires_at': expires,
  'is_active': active,
};

void main() {
  testWidgets(
    'guests list shows expiry and the menu clears it and deactivates',
    (t) async {
      await useTallSurface(t);
      final s = fakeSecurity();
      s.server.guests = [_guest()];
      await t.pumpWidget(
        faMaterial(
          home: Scaffold(
            body: SingleChildScrollView(child: GuestsCard(api: s.api)),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('External'), findsOneWidget);
      expect(find.textContaining('انقضا: ۱۴۷۷/'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('guest-menu-9')));
      await t.pumpAndSettle();
      await t.tap(find.text('حذف انقضا'));
      await t.pumpAndSettle();
      expect(s.server.lastBody('PATCH', '/manage/guests/9'), {
        'clear_expiry': true,
      });

      await t.tap(find.byKey(const ValueKey('guest-menu-9')));
      await t.pumpAndSettle();
      await t.tap(find.text('غیرفعال کردن'));
      await t.pumpAndSettle();
      expect(s.server.lastBody('POST', '/manage/users/9/active'), {
        'active': false,
      });
    },
  );

  testWidgets(
    'creating a guest validates, then posts email, name and password',
    (t) async {
      await useTallSurface(t);
      final s = fakeSecurity();
      await t.pumpWidget(
        faMaterial(
          home: Scaffold(
            body: SingleChildScrollView(child: GuestsCard(api: s.api)),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('مهمانی وجود ندارد'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('guest-new')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('guest-email')), 'bad');
      await t.tap(find.byKey(const ValueKey('guest-create')));
      await t.pumpAndSettle();
      expect(
        find.text('ایمیل معتبر و رمز حداقل ۸ نویسه لازم است'),
        findsOneWidget,
      );

      await t.enterText(
        find.byKey(const ValueKey('guest-email')),
        'new@x.test',
      );
      await t.enterText(find.byKey(const ValueKey('guest-name')), 'New Guest');
      await t.enterText(
        find.byKey(const ValueKey('guest-password')),
        'longenough1',
      );
      await t.tap(find.byKey(const ValueKey('guest-create')));
      await t.pumpAndSettle();
      expect(s.server.lastBody('POST', '/manage/guests'), {
        'email': 'new@x.test',
        'password': 'longenough1',
        'full_name': 'New Guest',
      });
      expect(find.text('New Guest'), findsOneWidget);
    },
  );

  testWidgets('a guest invitation code is created with guest: true and shown', (
    t,
  ) async {
    await useTallSurface(t);
    final s = fakeSecurity();
    await t.pumpWidget(
      faMaterial(
        home: Scaffold(
          body: SingleChildScrollView(child: GuestsCard(api: s.api)),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('guest-invite')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('invite-create')));
    await t.pumpAndSettle();
    final body = s.server.lastBody('POST', '/manage/invites')! as Map;
    expect(body['guest'], isTrue);
    expect(body['codes'], isEmpty);
    expect(find.text('GUEST-CODE-1'), findsOneWidget);
  });

  testWidgets('access editor re-roles, switches off and adds rows', (t) async {
    await useTallSurface(t);
    final s = fakeSecurity();
    await t.pumpWidget(
      faMaterial(
        home: UserAccessScreen(api: s.api, userId: 5, userName: 'Sara'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('access-role-p1')));
    await t.pumpAndSettle();
    await t.tap(find.text('بیننده').last);
    await t.pumpAndSettle();
    expect(s.server.lastBody('PUT', '/manage/users/5/access'), {
      'projects': [
        {'id': 'p1', 'active': true, 'role': 'viewer'},
      ],
      'customers': <Object>[],
      'conversations': <Object>[],
    });

    await t.tap(find.byKey(const ValueKey('access-active-p1')));
    await t.pumpAndSettle();
    expect(
      ((s.server.lastBody('PUT', '/access')! as Map)['projects'] as List)
          .single['active'],
      isFalse,
    );

    await t.tap(find.byKey(const ValueKey('access-add-projects')));
    await t.pumpAndSettle();
    expect(
      find.text('Alpha'),
      findsOneWidget,
    ); // already a member: only Beta is offered
    await t.tap(find.text('Beta'));
    await t.pumpAndSettle();
    final added =
        ((s.server.lastBody('PUT', '/access')! as Map)['projects'] as List)
                .single
            as Map;
    expect(added, {'id': 'p2', 'active': true, 'role': 'member'});
    expect(find.text('Beta'), findsOneWidget);
  });

  test('access rows keep the wire shape', () {
    final row = AccessRow.fromJson({
      'id': 'c1',
      'role': 'admin',
      'active': false,
      'name': 'G',
      'kind': 'group',
    });
    expect(row.copyWith(active: true).toWire(), {
      'id': 'c1',
      'active': true,
      'role': 'admin',
    });
  });
}
