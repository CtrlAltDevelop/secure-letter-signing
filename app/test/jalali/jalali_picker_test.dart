import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/jalali/jalali_picker.dart';
import 'package:letter_signing/workspace/widgets/jalali_date_field.dart';

import '../helpers.dart';

Finder day(int y, int m, int d) => find.byKey(
  Key(
    'jalali-day-$y-${m.toString().padLeft(2, '0')}-'
    '${d.toString().padLeft(2, '0')}',
  ),
);

String title(WidgetTester t) =>
    t.widget<Text>(find.byKey(const Key('jalali-title'))).data!;

Future<void> pump(
  WidgetTester t, {
  DateTime? selected,
  DateTime? first,
  DateTime? last,
  ValueChanged<DateTime>? onChanged,
}) async {
  await t.binding.setSurfaceSize(const Size(500, 800));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(
    faApp(
      JalaliCalendar(
        key: UniqueKey(),
        selected: selected,
        firstDate: first,
        lastDate: last,
        onChanged: onChanged ?? (_) {},
      ),
    ),
  );
}

void main() {
  testWidgets('selecting a day reports local midnight', (t) async {
    DateTime? picked;
    await pump(
      t,
      selected: DateTime(2026, 3, 21),
      onChanged: (d) => picked = d,
    );
    expect(title(t), 'فروردین ۱۴۰۵');
    await t.tap(day(1405, 1, 15));
    expect(picked, DateTime(2026, 4, 4));
  });

  testWidgets('month navigation crosses the year boundary', (t) async {
    await pump(t, selected: DateTime(2026, 3, 21));
    await t.tap(find.byKey(const Key('jalali-prev-month')));
    await t.pump();
    expect(title(t), 'اسفند ۱۴۰۴');
    await t.tap(find.byKey(const Key('jalali-next-month')));
    await t.tap(find.byKey(const Key('jalali-next-year')));
    await t.pump();
    expect(title(t), 'فروردین ۱۴۰۶');
    await t.tap(find.byKey(const Key('jalali-prev-year')));
    await t.pump();
    expect(title(t), 'فروردین ۱۴۰۵');
  });

  testWidgets('Esfand has 30 days in leap years 1403 and 1408 only', (t) async {
    // 1403-12-30 = 2025-03-20; 1408-12-30 = 2030-03-20.
    await pump(t, selected: DateTime(2025, 3, 20));
    expect(title(t), 'اسفند ۱۴۰۳');
    expect(day(1403, 12, 30), findsOneWidget);
    await pump(t, selected: DateTime(2030, 3, 20));
    expect(title(t), 'اسفند ۱۴۰۸');
    expect(day(1408, 12, 30), findsOneWidget);
    await pump(t, selected: DateTime(2026, 3, 20));
    expect(title(t), 'اسفند ۱۴۰۴');
    expect(day(1404, 12, 29), findsOneWidget);
    expect(day(1404, 12, 30), findsNothing);
  });

  testWidgets('weeks start on Saturday and Friday is the last column', (
    t,
  ) async {
    await pump(t, selected: DateTime(2026, 3, 21));
    // 1 Farvardin 1405 is a Saturday; in RTL the first column is rightmost.
    final first = t.getTopLeft(day(1405, 1, 1)).dx;
    final second = t.getTopLeft(day(1405, 1, 2)).dx;
    final friday = t.getTopLeft(day(1405, 1, 7)).dx;
    expect(first, greaterThan(second));
    expect(friday, lessThan(second));
  });

  testWidgets('min and max disable days and stop navigation', (t) async {
    DateTime? picked;
    await pump(
      t,
      selected: DateTime(2026, 3, 25),
      first: DateTime(2026, 3, 23),
      last: DateTime(2026, 4, 2),
      onChanged: (d) => picked = d,
    );
    await t.tap(day(1405, 1, 2)); // 2026-03-22 < min
    expect(picked, isNull);
    await t.tap(day(1405, 1, 13)); // 2026-04-02 = max
    expect(picked, DateTime(2026, 4, 2));
    await t.tap(day(1405, 1, 14)); // after max
    expect(picked, DateTime(2026, 4, 2));
    final prev = t.widget<IconButton>(
      find.byKey(const Key('jalali-prev-month')),
    );
    expect(prev.onPressed, isNull);
    final next = t.widget<IconButton>(
      find.byKey(const Key('jalali-next-month')),
    );
    expect(next.onPressed, isNull); // Ordibehesht starts 2026-04-21 > max
  });

  testWidgets('date field opens the dialog and returns the chosen date', (
    t,
  ) async {
    DateTime? value;
    await t.binding.setSurfaceSize(const Size(500, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      faApp(
        StatefulBuilder(
          builder: (context, setState) => JalaliDateField(
            value: value,
            onChanged: (d) => setState(() => value = d),
          ),
        ),
      ),
    );
    expect(find.text('انتخاب تاریخ'), findsOneWidget);
    await t.tap(find.byType(JalaliDateField));
    await t.pumpAndSettle();
    final cell = find.byWidgetPredicate(
      (w) => w is InkWell && '${w.key}'.contains('jalali-day-'),
    );
    await t.tap(cell.first);
    await t.pump();
    await t.tap(find.byKey(const Key('jalali-confirm')));
    await t.pumpAndSettle();
    expect(value, isNotNull);
    expect(find.byIcon(Icons.close), findsOneWidget);
    await t.tap(find.byIcon(Icons.close));
    await t.pump();
    expect(value, isNull);
  });
}
