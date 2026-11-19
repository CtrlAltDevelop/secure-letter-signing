import 'package:flutter/foundation.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:letter_signing/jalali/jalali_format.dart';

/// One Jalali month as a calendar grid: Saturday first, Friday the weekend. Pure logic shared
/// by calendar views; dates are local midnights.
@immutable
class JalaliMonth {
  const JalaliMonth(this.year, this.month);

  /// The month that contains [date] (local time).
  factory JalaliMonth.of(DateTime date) {
    final j = toJalali(date);
    return JalaliMonth(j.year, j.month);
  }

  final int year;
  final int month;

  Jalali get _first => Jalali(year, month, 1);

  int get length => _first.monthLength;

  /// Moves by [months] (negative goes back), crossing year boundaries.
  JalaliMonth shift(int months) {
    final total = year * 12 + (month - 1) + months;
    return JalaliMonth(total ~/ 12, total % 12 + 1);
  }

  /// First instant of the month, local time.
  DateTime get start => _first.toDateTime();

  /// First instant of the next month (exclusive end of the range).
  DateTime get end => shift(1).start;

  DateTime day(int d) => Jalali(year, month, d).toDateTime();

  /// Rows of 7 cells starting on Saturday; null cells pad the first and last week.
  List<List<int?>> weeks() {
    final cells = <int?>[
      for (var i = 0; i < _first.weekDay - 1; i++) null,
      for (var d = 1; d <= length; d++) d,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return [for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7)];
  }

  /// Persian title such as 'اسفند ۱۴۰۴'.
  String get title => '${jalaliMonthNames[month - 1]} ${toPersianDigits(year)}';

  /// Whether the 1-based Jalali [d] falls on a Friday.
  bool isFriday(int d) => Jalali(year, month, d).weekDay == 7;

  /// The day of this month that [date] falls on, or null for another month.
  int? dayOf(DateTime date) {
    final j = toJalali(date);
    return j.year == year && j.month == month ? j.day : null;
  }

  @override
  bool operator ==(Object other) =>
      other is JalaliMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}
