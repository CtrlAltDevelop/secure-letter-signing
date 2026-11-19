import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/sales/customer_leads_panel.dart';
import 'package:letter_signing/sales/lead_form_screen.dart';
import 'package:letter_signing/sales/models.dart';
import 'package:letter_signing/sales/sales_screen.dart';
import 'package:letter_signing/workspace/widgets/bar_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import '../letters/fakes.dart';
import 'sales_fixtures.dart';

const _sizes = [Size(375, 812), Size(844, 390)];

Future<void> _screen(WidgetTester t, FakeSalesServer s, Size size) async {
  await useTallSurface(t, size);
  await t.pumpWidget(faMaterial(home: SalesScreen(env: salesEnv(s).env)));
  await t.pumpAndSettle();
}

Future<void> _form(WidgetTester t, FakeSalesServer s, {Lead? lead, pick}) async {
  await useTallSurface(t, const Size(375, 1400));
  await t.pumpWidget(
    faMaterial(
      home: LeadFormScreen(env: salesEnv(s, pick: pick).env, lead: lead),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  test('LeadDraft patches only changed fields', () {
    final lead = Lead.fromJson(leadJson('a', title: 'X', value: 5, probability: 40));
    const same = LeadDraft(title: 'X', value: 5, probability: 40, ownerId: 2);
    expect(same.toPatchJson(lead), isEmpty);
    const changed = LeadDraft(title: 'X', value: 6, probability: 90, ownerId: 3);
    expect(changed.toPatchJson(lead), {'value': 6, 'probability': 90, 'owner_id': 3});
    expect(const LeadFilter(bucket: '0-24').toQuery()['probability_bucket'], '0-24');
  });

  for (final size in _sizes) {
    testWidgets('list shows leads with value and status at $size', (t) async {
      final s = FakeSalesServer()
        ..leads.addAll([
          leadJson('a', title: 'Big deal', value: 25000000, probability: 80),
          leadJson('b', title: 'Done', status: 'won', value: 700000),
        ]);
      await _screen(t, s, size);
      expect(find.text('Big deal'), findsOneWidget);
      expect(find.text('۲۵٬۰۰۰٬۰۰۰ ریال'), findsOneWidget);
      expect(find.text('موفق'), findsWidgets);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('status chip reaches the server; empty state', (t) async {
    final s = FakeSalesServer();
    await _screen(t, s, const Size(375, 900));
    expect(find.text('فرصت فروشی پیدا نشد'), findsOneWidget);
    await t.tap(find.text('ناموفق').first);
    await t.pumpAndSettle();
    expect(
      s.where('GET', '/sales/leads').last.url.queryParameters['status'],
      'lost',
    );
  });

  testWidgets('new lead posts title, value and the slider probability', (t) async {
    final s = FakeSalesServer();
    await _form(t, s, pick: pickPdf);
    await t.tap(find.text('ذخیره'));
    await t.pump();
    expect(find.text('عنوان را بنویسید.'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('lead-title')), 'Website');
    await t.enterText(find.byKey(const ValueKey('lead-value')), '۲٬۰۰۰٬۰۰۰');
    final slider = t.widget<Slider>(find.byKey(const ValueKey('lead-prob')));
    slider.onChanged!(75);
    await t.pump();
    expect(find.text('احتمال موفقیت: ۷۵٪'), findsOneWidget);
    expect(find.text('ارزش وزنی: ۱٬۵۰۰٬۰۰۰ ریال'), findsOneWidget);
    await t.tap(find.text('ذخیره'));
    await t.pumpAndSettle();
    final body = s.lastBody('POST', '/sales/leads')! as Map;
    expect(body['title'], 'Website');
    expect(body['value'], 2000000);
    expect(body['probability'], 75);
    await t.tap(find.text('بارگذاری پرونده'));
    await t.pumpAndSettle();
    expect(s.where('POST', '/files'), isNotEmpty);
  });

  testWidgets('win, lose with reason and reopen', (t) async {
    final s = FakeSalesServer()..leads.add(leadJson('a'));
    await _form(t, s, lead: Lead.fromJson(s.leads.first));
    await t.tap(find.byKey(const ValueKey('lead-win')));
    await t.pumpAndSettle();
    expect(s.where('POST', '/win'), hasLength(1));
    expect(find.byKey(const ValueKey('lead-reopen')), findsOneWidget);
    expect(find.text('ذخیره'), findsNothing);
    await t.tap(find.byKey(const ValueKey('lead-reopen')));
    await t.pumpAndSettle();
    expect(s.where('POST', '/reopen'), hasLength(1));
    await t.tap(find.byKey(const ValueKey('lead-lose')));
    await t.pumpAndSettle();
    await t.tap(find.text('ثبت'));
    await t.pump();
    expect(find.text('دلیل را بنویسید.'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('reason-field')), 'price');
    await t.tap(find.text('ثبت'));
    await t.pumpAndSettle();
    expect(s.lastBody('POST', '/lose'), {'reason': 'price'});
    expect(find.byKey(const ValueKey('lost-banner')), findsOneWidget);
  });

  testWidgets('a lead the user cannot edit has no save or actions', (t) async {
    final s = FakeSalesServer()..leads.add(leadJson('a', canEdit: false));
    await _form(t, s, lead: Lead.fromJson(s.leads.first));
    expect(find.text('ذخیره'), findsNothing);
    expect(find.byKey(const ValueKey('lead-win')), findsNothing);
  });

  testWidgets('monitor shows won vs probable chart and opens a bucket', (t) async {
    final s = FakeSalesServer()
      ..leads.addAll([
        leadJson('a', title: 'High', probability: 90),
        leadJson('b', title: 'Low', probability: 10),
      ]);
    await _screen(t, s, const Size(375, 1500));
    await t.tap(find.text('پایش فروش'));
    await t.pumpAndSettle();
    expect(find.text('۸٬۰۰۰٬۰۰۰'), findsWidgets);
    expect(find.text('۱۲٬۰۰۰٬۰۰۰'), findsWidgets);
    expect(find.byType(BarChart), findsNWidgets(2));
    await t.tap(find.byKey(const ValueKey('bucket-75-100')));
    await t.pumpAndSettle();
    expect(
      s.where('GET', '/sales/leads').last.url.queryParameters['probability_bucket'],
      '75-100',
    );
    expect(find.text('High'), findsOneWidget);
    expect(find.text('Low'), findsNothing);
  });

  testWidgets('customer leads panel lists the customer leads', (t) async {
    final s = FakeSalesServer()
      ..leads.add(leadJson('a', title: 'Acme deal', customerName: 'Acme'));
    await useTallSurface(t, const Size(375, 900));
    await t.pumpWidget(
      faMaterial(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CustomerLeadsPanel(env: salesEnv(s).env, customerId: 'c1'),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('فرصت‌های فروش مشتری'), findsOneWidget);
    expect(find.text('Acme deal'), findsOneWidget);
  });
}
