import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/letters/letter_detail_screen.dart';
import 'package:letter_signing/letters/letters_list_screen.dart';
import 'package:letter_signing/letters/letters_v2_api.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/letters/paper_pages.dart';
import 'package:letter_signing/letters/paper_preview.dart';
import 'package:letter_signing/letters/letterhead.dart';
import 'package:letter_signing/letters/rich/rich_doc.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';
import '../tasks/task_fixtures.dart';
import 'fakes.dart';
import 'letters_v2_fixtures.dart';

const _sizes = [Size(375, 812), Size(844, 390)];

Future<void> _openList(WidgetTester t, FakeLettersServer s) async {
  await t.pumpWidget(faMaterial(home: LettersListScreen(env: v2Env(s))));
  await t.pumpAndSettle();
}

Future<void> _openDetail(
  WidgetTester t,
  FakeLettersServer s, {
  dynamic tasks,
}) async {
  await t.pumpWidget(
    faMaterial(
      home: LetterDetailScreen(
        env: v2Env(s, tasks: tasks),
        letterId: 'L1',
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  group('list', () {
    testWidgets('boxes load per tab and show number label chips', (t) async {
      final s = FakeLettersServer()
        ..inbox = [v2Brief('L1', title: 'In one', numberLabel: '1405/0012')]
        ..outbox = [v2Brief('L2', title: 'Out one')];
      await useTallSurface(t, const Size(375, 812));
      await _openList(t, s);
      expect(find.text('In one'), findsOneWidget);
      expect(find.text('۱۴۰۵/۰۰۱۲'), findsOneWidget);
      expect(s.calls.first.url.queryParameters['box'], 'inbox');

      await t.tap(find.text('ارسالی'));
      await t.pumpAndSettle();
      expect(find.text('Out one'), findsOneWidget);
      expect(find.text('In one'), findsNothing);
      expect(s.calls.last.url.queryParameters['box'], 'outbox');
    });

    testWidgets('archive posts the mark and the card leaves on reload', (
      t,
    ) async {
      final s = FakeLettersServer();
      await useTallSurface(t, const Size(375, 812));
      await _openList(t, s);
      await t.tap(find.byTooltip('گزینه‌ها'));
      await t.pumpAndSettle();
      await t.tap(find.text('بایگانی کردن'));
      await t.pumpAndSettle();
      expect(s.lastBody('POST', '/archive'), {'archived': true});
    });

    testWidgets('labels render as chips and the sheet saves them', (t) async {
      final s = FakeLettersServer()
        ..inbox = [
          v2Brief('L1', title: 'Tagged', labelIds: [3]),
        ];
      await useTallSurface(t, const Size(375, 812));
      await _openList(t, s);
      expect(find.text('Urgent'), findsOneWidget);
      await t.tap(find.byTooltip('گزینه‌ها'));
      await t.pumpAndSettle();
      await t.tap(find.text('ویرایش برچسب‌ها'));
      await t.pumpAndSettle();
      await t.tap(find.text('ذخیره'));
      await t.pumpAndSettle();
      expect(s.lastBody('PUT', '/labels'), {
        'label_ids': [3],
      });
    });

    testWidgets('advanced search sends the criteria to /letters/search', (
      t,
    ) async {
      final s = FakeLettersServer()
        ..searchRows = [v2Brief('L9', title: 'Found by number')];
      await useTallSurface(t, const Size(375, 812));
      await _openList(t, s);
      await t.tap(find.byTooltip('جستجوی پیشرفته'));
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextField, 'شماره نامه'),
        '1405/0012',
      );
      await t.enterText(find.widgetWithText(TextField, 'امضاکننده'), 'ali');
      await t.pump();
      await t.tap(find.text('اعمال'));
      await t.pumpAndSettle();
      final req = s.calls.lastWhere((c) => c.url.path.endsWith('/search'));
      expect(req.url.queryParameters['number'], '1405/0012');
      expect(req.url.queryParameters['signer'], 'ali');
      expect(find.text('Found by number'), findsOneWidget);
    });

    testWidgets('the secretariat button shows only with the permission', (
      t,
    ) async {
      final s = FakeLettersServer();
      await useTallSurface(t, const Size(375, 812));
      await _openList(t, s);
      expect(find.byTooltip('دبیرخانه'), findsNothing);
      await t.pumpWidget(
        faMaterial(home: LettersListScreen(env: v2Env(s, secretariat: true))),
      );
      await t.pumpAndSettle();
      expect(find.byTooltip('دبیرخانه'), findsOneWidget);
    });

    for (final size in _sizes) {
      testWidgets('list fits ${size.width}x${size.height}', (t) async {
        final s = FakeLettersServer()
          ..inbox = [
            v2Brief(
              'L1',
              title: 'A fairly long letter title that wraps over lines',
              numberLabel: '1405/0012',
              labelIds: [3],
              referrals: 2,
            ),
          ];
        await useTallSurface(t, size);
        await _openList(t, s);
        expect(t.takeException(), isNull);
      });
    }
  });

  group('detail', () {
    testWidgets('referrals: refer sends people and note', (t) async {
      final s = FakeLettersServer();
      await useTallSurface(t, const Size(375, 1400));
      await _openDetail(t, s);
      await t.tap(find.text('ارجاع'));
      await t.pumpAndSettle();
      await t.tap(find.text('افزودن'));
      await t.pumpAndSettle();
      await t.tap(find.text('Bob'));
      await t.tap(find.text('تأیید'));
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextField, 'یادداشت (اختیاری)'),
        'please review',
      );
      await t.tap(find.text('ارسال ارجاع'));
      await t.pumpAndSettle();
      expect(s.lastBody('POST', '/refer'), {
        'user_ids': [3],
        'note': 'please review',
      });
      expect(find.textContaining('please review'), findsOneWidget);
    });

    testWidgets('referee marks a referral done', (t) async {
      final s = FakeLettersServer();
      s.referrals.add(referralJson(5, note: 'look'));
      await useTallSurface(t, const Size(375, 1400));
      await _openDetail(t, s);
      expect(find.text('در انتظار'), findsWidgets);
      await t.tap(find.widgetWithText(TextButton, 'انجام شد'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'تأیید'));
      await t.pumpAndSettle();
      expect(s.lastBody('POST', '/referrals/5/respond'), {
        'status': 'done',
        'note': '',
      });
    });

    testWidgets('tasks: link from the picker, then unlink', (t) async {
      final s = FakeLettersServer();
      final tasks = tasksFixture();
      await useTallSurface(t, const Size(375, 1600));
      await _openDetail(t, s, tasks: tasks);
      await t.tap(find.text('پیوند وظیفه'));
      await t.pumpAndSettle();
      expect(find.text('Pay invoice'), findsOneWidget);
      await t.tap(find.text('Pay invoice'));
      await t.pumpAndSettle();
      expect(s.lastBody('POST', '/letters/L1/tasks'), {'task_id': 't1'});
      expect(find.text('Pay invoice'), findsOneWidget);

      await t.tap(find.byTooltip('جدا کردن وظیفه'));
      await t.pumpAndSettle();
      expect(s.where('DELETE', '/letters/L1/tasks/t1'), hasLength(1));
      expect(find.text('وظیفه‌ای به این نامه وصل نشده است.'), findsOneWidget);
    });

    testWidgets('create task from the letter prefills the form', (t) async {
      final s = FakeLettersServer();
      final tasks = tasksFixture();
      await useTallSurface(t, const Size(375, 1600));
      await _openDetail(t, s, tasks: tasks);
      await t.tap(find.text('ایجاد وظیفه'));
      await t.pumpAndSettle();
      expect(
        find.widgetWithText(TextField, 'پیگیری نامه: Budget'),
        findsOneWidget,
      );
    });

    testWidgets('paraph with the PIN posts and lists the paraph', (t) async {
      final s = FakeLettersServer();
      await useTallSurface(t, const Size(375, 1600));
      await _openDetail(t, s);
      expect(find.text('هنوز پارافی ثبت نشده است.'), findsOneWidget);
      await t.tap(find.widgetWithText(OutlinedButton, 'پاراف'));
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextFormField, 'رمز امضا'),
        '123456',
      );
      await t.tap(find.widgetWithText(FilledButton, 'پاراف'));
      await t.pumpAndSettle();
      expect(s.lastBody('POST', '/paraph'), {'pin': '123456'});
      expect(find.text('هنوز پارافی ثبت نشده است.'), findsNothing);
      expect(find.textContaining('رمز'), findsWidgets);
    });

    testWidgets('paraph with biometrics uses the biometric endpoint', (
      t,
    ) async {
      final s = FakeLettersServer();
      await useTallSurface(t, const Size(375, 1600));
      await _openDetail(t, s);
      await t.tap(find.widgetWithText(OutlinedButton, 'پاراف'));
      await t.pumpAndSettle();
      await t.tap(find.text('اثر انگشت / چهره'));
      await t.pumpAndSettle();
      expect(s.where('POST', '/paraph-biometric'), hasLength(1));
    });

    testWidgets('number label, customer links and certificate paraphs', (
      t,
    ) async {
      final s = FakeLettersServer();
      s.detail['number_label'] = '1405/0012';
      s.detail['customer_refs'] = ['cust-1'];
      s.certificate = {
        'signatures': <Map<String, dynamic>>[],
        'all_verified': true,
        'paraphs': [
          {'signer': 'me@x.test', 'method': 'pin', 'verified': true},
        ],
        'paraphs_verified': true,
      };
      await useTallSurface(t, const Size(375, 1600));
      await _openDetail(t, s);
      expect(find.text('۱۴۰۵/۰۰۱۲'), findsOneWidget);
      expect(find.text('cust-1'), findsOneWidget);
      await t.tap(find.byTooltip('گواهی امضا'));
      await t.pumpAndSettle();
      expect(find.text('پاراف‌ها تأیید شد'), findsOneWidget);
    });

    for (final size in _sizes) {
      testWidgets('detail fits ${size.width}x${size.height}', (t) async {
        final s = FakeLettersServer();
        s.referrals.add(referralJson(5, note: 'look'));
        s.detail['tasks'] = [briefTask('t1', title: 'Pay invoice')];
        s.detail['paraphs'] = [
          {
            'signer_id': 2,
            'signer_name': 'Me',
            'method': 'pin',
            'device_name': 'laptop',
            'paraphed_at': '2026-01-02T03:04:05Z',
          },
        ];
        await t.binding.setSurfaceSize(size);
        t.view.devicePixelRatio = 1;
        addTearDown(() {
          t.view.resetDevicePixelRatio();
          t.binding.setSurfaceSize(null);
        });
        await _openDetail(t, s, tasks: tasksFixture());
        expect(t.takeException(), isNull);
      });
    }
  });

  group('paper', () {
    testWidgets('number label and paraphs appear in the print page', (t) async {
      await useTallSurface(t, const Size(900, 1300));
      final doc = PaperDocument(
        head: const Letterhead(name: 'Acme'),
        title: 'Budget',
        number: '۱۴۰۵/۰۰۱۲',
        date: '۱۴۰۵/۰۱/۰۱',
        text: RichDoc.plain('hello'),
        paraphs: const [
          PaperParaph(name: 'Ali', method: 'رمز', date: '۱۴۰۵/۰۱/۰۲'),
        ],
      );
      await t.pumpWidget(
        faMaterial(
          home: Scaffold(body: PaperPreview(doc: doc, fontSize: 12)),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('شماره: ۱۴۰۵/۰۰۱۲'), findsOneWidget);
      expect(find.text('پاراف‌ها'), findsOneWidget);
      expect(find.textContaining('Ali'), findsOneWidget);
    });
  });

  test('LetterSearch counts its criteria and builds the query', () {
    const c = LetterSearch(number: '12', signer: 'x', box: 'inbox');
    expect(c.activeCount, 2);
    final q = c.toQuery();
    expect(q['box'], 'inbox');
    expect(q['number'], '12');
    expect(const LetterSearch().isEmpty, isTrue);
  });

  test('LetterBrief and detail parse the v2 fields', () {
    final d = LetterDetail.fromJson({
      ...detailJson(v2Brief('L1', numberLabel: '1405/0001', labelIds: [3])),
      'paraphs': [
        {
          'signer_id': 2,
          'signer_name': 'Me',
          'method': 'pin',
          'device_name': 'd',
          'paraphed_at': '2026-01-02T03:04:05Z',
        },
      ],
      'tasks': [briefTask('t1')],
      'customer_refs': ['c1'],
    });
    expect(d.brief.numberLabel, '1405/0001');
    expect(d.brief.labelIds, [3]);
    expect(d.paraphs.single.signerName, 'Me');
    expect(d.tasks.single.id, 't1');
    expect(d.customerRefs, ['c1']);
  });
}
