import 'package:flutter_test/flutter_test.dart';
import 'package:letter_signing/jalali/jalali_format.dart';

void main() {
  test('2026-03-21 is 1405/01/01 with Persian digits', () {
    expect(formatJalaliDate(DateTime(2026, 3, 21)), '۱۴۰۵/۰۱/۰۱');
  });

  test('long format names weekday and month', () {
    // 2026-03-21 is a Saturday.
    expect(formatJalaliLong(DateTime(2026, 3, 21)), 'شنبه ۱ فروردین ۱۴۰۵');
    expect(formatJalaliLong(DateTime(2026, 3, 27)), startsWith('جمعه'));
  });

  test('time and date-time use Persian digits', () {
    final d = DateTime(2026, 3, 21, 14, 5);
    expect(formatJalaliTime(d), '۱۴:۰۵');
    expect(formatJalaliDateTime(d), '۱۴۰۵/۰۱/۰۱ ۱۴:۰۵');
  });

  test('UTC values are shown in local time', () {
    final utc = DateTime.utc(2026, 3, 21, 12);
    expect(formatJalaliDate(utc), formatJalaliDate(utc.toLocal()));
    expect(toUtcIso(DateTime(2026, 3, 21, 12)).endsWith('Z'), isTrue);
  });

  test('toPersianDigits only touches digits', () {
    expect(toPersianDigits('a1b2'), 'a۱b۲');
  });

  group('formatRelative', () {
    final now = DateTime(2026, 3, 21, 12);
    test('minutes, hours, days in the past and future', () {
      expect(formatRelative(now, now: now), 'همین حالا');
      expect(
        formatRelative(now.subtract(const Duration(minutes: 5)), now: now),
        '۵ دقیقه پیش',
      );
      expect(
        formatRelative(now.add(const Duration(hours: 3)), now: now),
        '۳ ساعت دیگر',
      );
      expect(formatRelative(DateTime(2026, 3, 20, 8), now: now), 'دیروز');
      expect(formatRelative(DateTime(2026, 3, 22, 18), now: now), 'فردا');
      expect(formatRelative(DateTime(2026, 3, 18, 8), now: now), '۳ روز پیش');
    });
    test('falls back to the date after a week', () {
      expect(formatRelative(DateTime(2026, 2, 1), now: now), '۱۴۰۴/۱۱/۱۲');
    });
  });
}
