import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/crm/customer_detail_screen.dart';
import 'package:letter_signing/crm/customer_form_screen.dart';
import 'package:letter_signing/crm/customer_import_screen.dart';
import 'package:letter_signing/crm/customers_screen.dart';
import 'package:letter_signing/crm/models.dart';
import 'package:letter_signing/workspace/file_pick.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import '../letters/fakes.dart';
import 'crm_fixtures.dart';

Future<void> _pump(
  WidgetTester t,
  Widget home, [
  Size size = const Size(375, 900),
]) async {
  await useTallSurface(t, size);
  await t.pumpWidget(faMaterial(home: home));
  await t.pumpAndSettle();
}

Future<void> _tab(WidgetTester t, String label) async {
  final tab = find.widgetWithText(Tab, label);
  await t.ensureVisible(tab);
  await t.pumpAndSettle();
  await t.tap(tab);
  await t.pumpAndSettle();
}

void main() {
  test('CustomerDraft patches only changed fields; filter query', () {
    final c = Customer.fromJson(customerJson('a', name: 'X'));
    final same = CustomerDraft.fromCustomer(c);
    expect(same.patchAgainst(c), isEmpty);
    expect(same.copyWith(name: 'Y ', status: 'archived').patchAgainst(c), {
      'name': 'Y',
      'status': 'archived',
    });
    final q = const CustomerFilter(
      statuses: {'active', 'inactive'},
      labelId: 3,
    ).toQuery();
    expect(q['status'], 'active,inactive');
    expect(q['label'], 3);
  });

  for (final size in const [Size(375, 812), Size(844, 390)]) {
    testWidgets('list shows customers at $size', (t) async {
      final s = FakeCrmServer()
        ..customers.addAll([
          customerJson('a', name: 'Acme'),
          customerJson('b', name: 'Reza', kind: 'person', status: 'inactive'),
        ]);
      await _pump(t, CustomersScreen(env: crmEnv(s).env), size);
      expect(find.text('Acme'), findsOneWidget);
      expect(find.text('Reza'), findsOneWidget);
      expect(find.text('غیرفعال'), findsWidgets);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets(
    'search and status filter reach the server; import only with permission',
    (t) async {
      final s = FakeCrmServer()..customers.add(customerJson('a'));
      await _pump(t, CustomersScreen(env: crmEnv(s).env));
      expect(find.byKey(const ValueKey('crm-import')), findsNothing);
      await t.enterText(find.byType(TextField).first, 'ac');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
      expect(s.where('GET', '/customers').last.url.queryParameters['q'], 'ac');
      await t.tap(find.text('بایگانی').first);
      await t.pumpAndSettle();
      expect(
        s.where('GET', '/customers').last.url.queryParameters['status'],
        'archived',
      );
      await _pump(t, CustomersScreen(env: crmEnv(s, canImport: true).env));
      expect(find.byKey(const ValueKey('crm-import')), findsOneWidget);
    },
  );

  testWidgets('create posts the form; a 409 shows the limit notice', (t) async {
    final s = FakeCrmServer();
    await _pump(t, CustomerFormScreen(env: crmEnv(s).env));
    await t.tap(find.byKey(const ValueKey('crm-save')));
    await t.pumpAndSettle();
    expect(find.text('نام را وارد کنید.'), findsOneWidget);
    expect(s.where('POST', '/customers'), isEmpty);
    await t.enterText(find.byType(TextField).first, 'Nova');
    s.limitReached = true;
    await t.tap(find.byKey(const ValueKey('crm-save')));
    await t.pumpAndSettle();
    expect(find.text('سقف تعداد پرونده‌های مشتری پر شده است.'), findsOneWidget);
    s.limitReached = false;
    await t.tap(find.byKey(const ValueKey('crm-save')));
    await t.pumpAndSettle();
    expect((s.lastBody('POST', '/customers') as Map)['name'], 'Nova');
    expect(s.customers, hasLength(1));
  });

  testWidgets('detail: timeline note, tasks tab, calls to task', (t) async {
    final s = FakeCrmServer()..customers.add(customerJson('a'));
    s.tasks.add({
      'id': 't1',
      'subject_id': 'ts',
      'title': 'Call back',
      'status': 'open',
    });
    await _pump(t, CustomerDetailScreen(env: crmEnv(s).env, customerId: 'a'));
    expect(find.text('Acme'), findsWidgets);
    await _tab(t, 'خط زمانی');
    await t.enterText(find.byKey(const ValueKey('crm-note')), 'met in person');
    await t.tap(find.byKey(const ValueKey('crm-note-add')));
    await t.pumpAndSettle();
    expect(s.lastBody('POST', '/events'), {
      'kind': 'note',
      'summary': 'met in person',
    });
    expect(find.text('met in person'), findsOneWidget);

    await _tab(t, 'وظایف');
    expect(find.text('Call back'), findsOneWidget);
    expect(find.byKey(const ValueKey('crm-linked-create')), findsOneWidget);

    await _tab(t, 'گزارش تماس');
    await t.tap(find.byKey(const ValueKey('crm-call-add')));
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const ValueKey('crm-call-summary')),
      'asked price',
    );
    await t.tap(find.byKey(const ValueKey('crm-call-save')));
    await t.pumpAndSettle();
    expect((s.lastBody('POST', '/calls') as Map)['summary'], 'asked price');
    final callId = s.calls.first['id'];
    await t.tap(find.byKey(ValueKey('crm-call-task-$callId')));
    await t.pumpAndSettle();
    expect(s.where('POST', '/to-task'), hasLength(1));
  });

  testWidgets('letters tab links and unlinks a letter', (t) async {
    final s = FakeCrmServer()..customers.add(customerJson('a'));
    s.letterLinks['L1'] = [];
    await _pump(t, CustomerDetailScreen(env: crmEnv(s).env, customerId: 'a'));
    await _tab(t, 'نامه‌ها');
    await t.tap(find.byKey(const ValueKey('crm-linked-create')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('crm-letter-pick-L1')));
    await t.pumpAndSettle();
    expect(s.letterLinks['L1'], ['a']);
    expect(find.text('Letter L1'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('crm-letter-unlink-L1')));
    await t.pumpAndSettle();
    expect(s.letterLinks['L1'], isEmpty);
  });

  testWidgets(
    'viewer cannot add notes, calls or edit; panels hidden without host',
    (t) async {
      final s = FakeCrmServer()
        ..customers.add(customerJson('a', role: 'viewer'));
      await _pump(t, CustomerDetailScreen(env: crmEnv(s).env, customerId: 'a'));
      expect(find.byKey(const ValueKey('crm-edit')), findsNothing);
      expect(find.byKey(const ValueKey('crm-polls')), findsOneWidget);
      expect(find.text('مالی'), findsNothing);
      await _tab(t, 'خط زمانی');
      expect(find.byKey(const ValueKey('crm-note')), findsNothing);
      await _tab(t, 'وظایف');
      expect(find.byKey(const ValueKey('crm-linked-create')), findsNothing);
    },
  );

  testWidgets('finance and leads tabs appear when the host provides them', (
    t,
  ) async {
    final s = FakeCrmServer()..customers.add(customerJson('a'));
    await _pump(
      t,
      CustomerDetailScreen(env: crmEnv(s, panels: true).env, customerId: 'a'),
    );
    await _tab(t, 'مالی');
    expect(find.text('finance-panel'), findsOneWidget);
    await _tab(t, 'فروش');
    expect(find.text('leads-panel'), findsOneWidget);
  });

  testWidgets('members: add a member and change a role', (t) async {
    final s = FakeCrmServer()..customers.add(customerJson('a'));
    await _pump(t, CustomerDetailScreen(env: crmEnv(s).env, customerId: 'a'));
    await _tab(t, 'اعضا');
    await t.tap(find.byKey(const ValueKey('crm-member-add')));
    await t.pumpAndSettle();
    await t.tap(find.text('Sara'));
    await t.pumpAndSettle();
    await t.tap(find.byType(FilledButton).last);
    await t.pumpAndSettle();
    final body = s.lastBody('PUT', '/members') as List;
    expect(body.map((e) => (e as Map)['user_id']), containsAll([2, 3]));
    expect(find.text('Sara'), findsOneWidget);
  });

  testWidgets('import shows per-row results', (t) async {
    final s = FakeCrmServer();
    Future<PickedFile?> pick() async => PickedFile(
      name: 'c.xlsx',
      bytes: Uint8List.fromList([1]),
      contentType: 'application/octet-stream',
    );
    await _pump(
      t,
      CustomerImportScreen(env: crmEnv(s, canImport: true, pick: pick).env),
    );
    await t.tap(find.byKey(const ValueKey('crm-import-pick')));
    await t.pumpAndSettle();
    expect(find.text('name is required'), findsOneWidget);
    expect(find.textContaining('۲ ایجاد'), findsOneWidget);
    expect(s.where('POST', '/customers/import'), hasLength(1));
  });
}
