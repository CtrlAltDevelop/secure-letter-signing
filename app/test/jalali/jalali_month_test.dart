import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/jalali/jalali_month.dart';

void main() {
  test('shift crosses the year boundary both ways', () {
    expect(const JalaliMonth(1404, 12).shift(1), const JalaliMonth(1405, 1));
    expect(const JalaliMonth(1405, 1).shift(-1), const JalaliMonth(1404, 12));
    expect(const JalaliMonth(1404, 11).shift(14), const JalaliMonth(1406, 1));
  });

  test('Farvardin 1405 starts on a Saturday (2026-03-21), Friday last', () {
    const m = JalaliMonth(1405, 1);
    expect(m.start, DateTime(2026, 3, 21));
    expect(m.length, 31);
    final weeks = m.weeks();
    expect(weeks.first.first, 1);
    expect(weeks.first.last, 7);
    expect(m.isFriday(7), isTrue);
    expect(weeks.every((w) => w.length == 7), isTrue);
  });

  test('leap Esfand 1403 has 30 days and the range ends at Nowruz 1404', () {
    const m = JalaliMonth(1403, 12);
    expect(m.length, 30);
    expect(m.end, DateTime(2025, 3, 21));
    expect(m.dayOf(DateTime(2025, 3, 20)), 30);
    expect(m.dayOf(DateTime(2025, 3, 21)), isNull);
    expect(m.title, 'اسفند ۱۴۰۳');
  });
}
