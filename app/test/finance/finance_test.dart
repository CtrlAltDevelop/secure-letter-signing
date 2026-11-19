import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/finance/customer_finance_panel.dart';
import 'package:letter_signing/finance/finance_form_screen.dart';
import 'package:letter_signing/finance/finance_screen.dart';
import 'package:letter_signing/finance/models.dart';
import 'package:letter_signing/workspace/money.dart';
import 'package:letter_signing/workspace/widgets/bar_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import '../letters/fakes.dart';
import 'finance_fixtures.dart';

const _sizes = [Size(375, 812), Size(844, 390)];

Future<void> _screen(WidgetTester t, FakeFinanceServer s, Size size) async {
  await useTallSurface(t, size);
  await t.pumpWidget(faMaterial(home: FinanceScreen(env: financeEnv(s).env)));
  await t.pumpAndSettle();
}

Future<void> _form(
  WidgetTester t,
  FakeFinanceServer s, {
  FinanceDoc? doc,
  pick,
}) async {
  await useTallSurface(t, const Size(375, 1200));
  await t.pumpWidget(
    faMaterial(
      home: FinanceFormScreen(
        env: financeEnv(s, pick: pick).env,
        doc: doc,
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  test('amount helpers format and parse Persian numbers', () {
    expect(formatAmount(1234567), '۱٬۲۳۴٬۵۶۷');
    expect(formatAmount(-1000), '-۱٬۰۰۰');
    expect(parseAmount('۱٬۲۰۰'), 1200);
    expect(parseAmount('1,500'), 1500);
    expect(parseAmount('12a'), isNull);
    expect(parseAmount(''), isNull);
    expect(dayIso(DateTime(2026, 5, 1)), '2026-05-01');
  });

  test(
    'FinanceDraft sends due date only for non-cash and patches the diff',
    () {
      final draft = FinanceDraft(
        kind: FinanceKind.cash,
        direction: FinanceDirection.payment,
        amount: 5,
        date: DateTime(2026, 5, 1),
        dueDate: DateTime(2026, 6, 1),
      );
      expect(draft.toCreateJson().containsKey('due_date'), isFalse);
      final doc = FinanceDoc.fromJson(
        docJson('a', amount: 5, direction: 'payment'),
      );
      expect(draft.toPatchJson(doc), isEmpty);
      expect(
        FinanceDraft(
          kind: 'cash',
          direction: 'payment',
          amount: 9,
          date: DateTime(2026, 5, 1),
        ).toPatchJson(doc),
        {'amount': 9},
      );
    },
  );

  for (final size in _sizes) {
    testWidgets('list shows amounts, status and overdue at $size', (t) async {
      final s = FakeFinanceServer()
        ..docs.addAll([
          docJson('a', amount: 1500000, description: 'rent'),
          docJson(
            'b',
            kind: 'cheque',
            status: 'pending',
            due: '2026-05-10',
            overdue: true,
            direction: 'payment',
            amount: 250000,
          ),
        ]);
      await _screen(t, s, size);
      expect(find.text('۱٬۵۰۰٬۰۰۰ ریال'), findsOneWidget);
      expect(find.text('سررسید گذشته'), findsOneWidget);
      expect(find.text('در انتظار'), findsWidgets);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('direction and status chips reach the server', (t) async {
    final s = FakeFinanceServer()..docs.add(docJson('a'));
    await _screen(t, s, const Size(375, 900));
    await t.tap(find.text('پرداخت').first);
    await t.pumpAndSettle();
    expect(
      s.where('GET', '/finance/docs').last.url.queryParameters['direction'],
      'payment',
    );
    await t.tap(find.text('باطل‌شده').first);
    await t.pumpAndSettle();
    expect(
      s.where('GET', '/finance/docs').last.url.queryParameters['status'],
      'void',
    );
  });

  testWidgets('empty state', (t) async {
    await _screen(t, FakeFinanceServer(), const Size(375, 812));
    expect(find.text('سندی پیدا نشد'), findsOneWidget);
  });

  testWidgets('new cash document posts the body, then offers files', (t) async {
    final s = FakeFinanceServer();
    await _form(t, s, pick: pickPdf);
    expect(
      find.text('برای پیوست فایل، ابتدا سند را ذخیره کنید.'),
      findsOneWidget,
    );
    await t.tap(find.text('ذخیره'));
    await t.pump();
    expect(find.text('مبلغ باید عددی مثبت باشد.'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('fin-amount')), '۱٬۲۰۰');
    await t.enterText(find.byKey(const ValueKey('fin-description')), 'rent');
    await t.tap(find.text('پرداخت'));
    await t.pump();
    await t.tap(find.text('ذخیره'));
    await t.pumpAndSettle();
    final body = s.lastBody('POST', '/finance/docs')! as Map;
    expect(body['amount'], 1200);
    expect(body['kind'], 'cash');
    expect(body['direction'], 'payment');
    expect((body['description'] as Map)['text'], 'rent');
    expect(body.containsKey('due_date'), isFalse);
    // Saved: the files section replaces the hint and an upload reaches the server.
    expect(find.text('پیوست‌ها'), findsOneWidget);
    await t.tap(find.text('بارگذاری پرونده'));
    await t.pumpAndSettle();
    expect(s.where('POST', '/files'), isNotEmpty);
    expect(find.text('cheque.pdf'), findsOneWidget);
  });

  testWidgets('a cheque without due date is refused before any request', (
    t,
  ) async {
    final s = FakeFinanceServer();
    await _form(t, s);
    await t.tap(find.text('چک'));
    await t.enterText(find.byKey(const ValueKey('fin-amount')), '100');
    await t.tap(find.text('ذخیره'));
    await t.pump();
    expect(
      find.text('برای چک و سند احتمالی تاریخ سررسید لازم است.'),
      findsOneWidget,
    );
    expect(s.where('POST', '/finance/docs'), isEmpty);
  });

  testWidgets('void asks for a reason, then shows the banner', (t) async {
    final s = FakeFinanceServer()
      ..docs.add(
        docJson('a', kind: 'cheque', status: 'pending', due: '2026-06-01'),
      );
    await _form(t, s, doc: FinanceDoc.fromJson(s.docs.first));
    await t.tap(find.byTooltip('ابطال سند'));
    await t.pumpAndSettle();
    await t.tap(find.text('ابطال'));
    await t.pump();
    expect(find.text('دلیل را بنویسید.'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('reason-field')), 'typo');
    await t.tap(find.text('ابطال'));
    await t.pumpAndSettle();
    expect(s.lastBody('POST', '/void'), {'reason': 'typo'});
    expect(find.byKey(const ValueKey('void-banner')), findsOneWidget);
    expect(find.text('ذخیره'), findsNothing);
  });

  testWidgets('confirm turns a pending document into a confirmed one', (
    t,
  ) async {
    final s = FakeFinanceServer()
      ..docs.add(
        docJson('a', kind: 'probable', status: 'pending', due: '2026-06-01'),
      );
    await _form(t, s, doc: FinanceDoc.fromJson(s.docs.first));
    await t.tap(find.byTooltip('قطعی‌سازی'));
    await t.pumpAndSettle();
    expect(s.where('POST', '/confirm'), hasLength(1));
    expect(find.byTooltip('قطعی‌سازی'), findsNothing);
  });

  testWidgets('report shows the table, chart and drills into a month', (
    t,
  ) async {
    final s = FakeFinanceServer()..docs.add(docJson('a'));
    await _screen(t, s, const Size(375, 1400));
    await t.tap(find.text('گزارش'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-table')), findsOneWidget);
    expect(find.text('اردیبهشت ۱۴۰۵'), findsOneWidget);
    expect(find.text('۳٬۰۰۰٬۰۰۰'), findsWidgets);
    expect(find.byType(BarChart), findsOneWidget);
    await t.tap(find.text('اردیبهشت ۱۴۰۵'));
    await t.pumpAndSettle();
    final q = s.where('GET', '/finance/docs').last.url.queryParameters;
    expect(q['from'], '2026-04-21');
    expect(q['to'], '2026-05-21');
    expect(q['status'], 'confirmed,pending');
    expect(find.text('اسناد اردیبهشت ۱۴۰۵'), findsOneWidget);
    t.state<NavigatorState>(find.byType(Navigator)).pop();
    await t.pumpAndSettle();
    await t.tap(find.text('سالانه'));
    await t.pumpAndSettle();
    expect(
      s.where('GET', '/finance/summary').last.url.queryParameters['group_by'],
      'year',
    );
    expect(find.text('۱۴۰۵'), findsWidgets);
  });

  testWidgets('monitor lists pending receipts, overdue first', (t) async {
    final s = FakeFinanceServer()
      ..docs.addAll([
        docJson(
          'late',
          kind: 'cheque',
          status: 'pending',
          due: '2026-05-01',
          overdue: true,
          amount: 700000,
        ),
        docJson(
          'soon',
          kind: 'probable',
          status: 'pending',
          due: '2026-07-01',
          amount: 300000,
        ),
      ]);
    await _screen(t, s, const Size(375, 1200));
    await t.tap(find.text('پایش'));
    await t.pumpAndSettle();
    final q = s.where('GET', '/finance/docs').last.url.queryParameters;
    expect(q['direction'], 'receipt');
    expect(q['status'], 'pending');
    expect(find.byKey(const ValueKey('monitor-totals')), findsOneWidget);
    expect(
      t.getTopLeft(find.byKey(const ValueKey('fin-late'))).dy <
          t.getTopLeft(find.byKey(const ValueKey('fin-soon'))).dy,
      isTrue,
    );
  });

  testWidgets('customer panel shows totals and documents', (t) async {
    final s = FakeFinanceServer()
      ..docs.add(docJson('a', customerName: 'Acme', amount: 1500000));
    await useTallSurface(t, const Size(375, 900));
    await t.pumpWidget(
      faMaterial(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CustomerFinancePanel(
              env: financeEnv(s).env,
              customerId: 'c1',
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('گزارش مالی مشتری'), findsOneWidget);
    expect(find.byKey(const ValueKey('fin-a')), findsOneWidget);
    expect(s.where('GET', '/customers/c1/finance'), hasLength(1));
  });
}
