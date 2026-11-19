import 'package:shamsi_date/shamsi_date.dart';

/// Jalali (Persian calendar) display helpers. Dates are stored and sent as UTC ISO strings;
/// every function here converts to local time only to show a value.

const jalaliMonthNames = [
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند',
];

/// Indexed by [Jalali.weekDay] - 1: Saturday first, Friday last.
const jalaliWeekdayNames = [
  'شنبه',
  'یکشنبه',
  'دوشنبه',
  'سه‌شنبه',
  'چهارشنبه',
  'پنجشنبه',
  'جمعه',
];

const _persianDigits = '۰۱۲۳۴۵۶۷۸۹';

/// Replaces ASCII digits with Persian ones.
String toPersianDigits(Object value) => '$value'.replaceAllMapped(
  RegExp('[0-9]'),
  (m) => _persianDigits[int.parse(m[0]!)],
);

String _two(int n) => n.toString().padLeft(2, '0');

/// The Jalali date of [value] in local time.
Jalali toJalali(DateTime value) => Jalali.fromDateTime(value.toLocal());

/// Local midnight of a Jalali date, as a [DateTime].
DateTime jalaliToDateTime(int year, int month, int day) =>
    Jalali(year, month, day).toDateTime();

/// The wire format: UTC ISO 8601.
String toUtcIso(DateTime value) => value.toUtc().toIso8601String();

/// '۱۴۰۵/۰۱/۰۱'.
String formatJalaliDate(DateTime value) {
  final j = toJalali(value);
  return toPersianDigits('${j.year}/${_two(j.month)}/${_two(j.day)}');
}

/// 'شنبه ۱ فروردین ۱۴۰۵'.
String formatJalaliLong(DateTime value) {
  final j = toJalali(value);
  return '${jalaliWeekdayNames[j.weekDay - 1]} '
      '${toPersianDigits(j.day)} ${jalaliMonthNames[j.month - 1]} '
      '${toPersianDigits(j.year)}';
}

/// '۱۴:۰۵' (24 hour clock).
String formatJalaliTime(DateTime value) {
  final t = value.toLocal();
  return toPersianDigits('${_two(t.hour)}:${_two(t.minute)}');
}

/// '۱۴۰۵/۰۱/۰۱ ۱۴:۰۵'.
String formatJalaliDateTime(DateTime value) =>
    '${formatJalaliDate(value)} ${formatJalaliTime(value)}';

/// 'همین حالا', '۵ دقیقه پیش', 'فردا', '۳ روز دیگر'; beyond a week it falls back to the date.
String formatRelative(DateTime when, {DateTime? now}) {
  final current = (now ?? DateTime.now()).toLocal();
  final local = when.toLocal();
  final diff = current.difference(local);
  final past = !diff.isNegative;
  final span = diff.abs();
  String ago(int n, String unit) =>
      '${toPersianDigits(n)} $unit ${past ? 'پیش' : 'دیگر'}';
  if (span < const Duration(minutes: 1)) return 'همین حالا';
  if (span < const Duration(hours: 1)) return ago(span.inMinutes, 'دقیقه');
  if (span < const Duration(hours: 24)) return ago(span.inHours, 'ساعت');
  final days = _calendarDays(local, current);
  if (days == 0) return 'امروز';
  if (days == -1) return 'دیروز';
  if (days == 1) return 'فردا';
  if (days.abs() <= 7) return ago(days.abs(), 'روز');
  return formatJalaliDate(local);
}

/// Whole calendar days from [to] to [from] (positive when [from] is later), DST-safe.
int _calendarDays(DateTime from, DateTime to) => DateTime.utc(
  from.year,
  from.month,
  from.day,
).difference(DateTime.utc(to.year, to.month, to.day)).inDays;
