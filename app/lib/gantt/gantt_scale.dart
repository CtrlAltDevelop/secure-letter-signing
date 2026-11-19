import 'package:flutter/foundation.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:letter_signing/gantt/gantt_models.dart';
import 'package:letter_signing/jalali/jalali_format.dart';

enum GanttZoom { daily, monthly, quarterly }

const _dayWidths = {
  GanttZoom.daily: 28.0,
  GanttZoom.monthly: 6.0,
  GanttZoom.quarterly: 2.0,
};
const _seasonNames = ['بهار', 'تابستان', 'پاییز', 'زمستان'];

Jalali jalaliOf(DateTime day) =>
    Jalali.fromDateTime(DateTime(day.year, day.month, day.day));

DateTime dayOf(Jalali j) => asDay(j.toDateTime());

/// A labelled stretch of the time axis (a Jalali month, year, quarter or day).
@immutable
class HeaderSegment {
  const HeaderSegment(this.label, this.startDay, this.days);
  final String label;

  /// Days after [GanttScale.origin].
  final int startDay;
  final int days;
}

/// Maps days to horizontal pixels for one zoom level. The axis starts on the first day of the
/// Jalali month holding the first date and ends on the last day of the month holding the last.
@immutable
class GanttScale {
  const GanttScale({
    required this.origin,
    required this.days,
    required this.zoom,
  });

  factory GanttScale.fit(
    DateTime? start,
    DateTime? end,
    GanttZoom zoom, {
    DateTime? today,
  }) {
    var from = start ?? today ?? DateTime.now();
    var to = end ?? from;
    if (to.isBefore(from)) to = from;
    final first = jalaliOf(from);
    final last = jalaliOf(to);
    final origin = dayOf(Jalali(first.year, first.month, 1));
    final lastDay = dayOf(Jalali(last.year, last.month, last.monthLength));
    return GanttScale(
      origin: origin,
      days: daysBetween(origin, lastDay) + 1,
      zoom: zoom,
    );
  }

  final DateTime origin;
  final int days;
  final GanttZoom zoom;

  double get dayWidth => _dayWidths[zoom]!;
  double get width => days * dayWidth;

  DateTime dayAt(int offset) => origin.add(Duration(days: offset));

  /// Left edge of [day].
  double x(DateTime day) => daysBetween(origin, day) * dayWidth;

  /// The day under pixel [px] (clamped to the axis).
  DateTime dayUnder(double px) =>
      dayAt((px / dayWidth).floor().clamp(0, days - 1));

  List<HeaderSegment> _months() {
    final out = <HeaderSegment>[];
    var offset = 0;
    while (offset < days) {
      final j = jalaliOf(dayAt(offset));
      final len = (j.monthLength - j.day + 1).clamp(1, days - offset);
      out.add(HeaderSegment(jalaliMonthNames[j.month - 1], offset, len));
      offset += len;
    }
    return out;
  }

  /// Upper header row: months (daily zoom) or years (monthly / quarterly).
  List<HeaderSegment> get top => zoom == GanttZoom.daily ? _months() : _years();

  /// Lower header row: day numbers, month names or seasons.
  List<HeaderSegment> get bottom => switch (zoom) {
    GanttZoom.daily => [
      for (var i = 0; i < days; i++)
        HeaderSegment(toPersianDigits(jalaliOf(dayAt(i)).day), i, 1),
    ],
    GanttZoom.monthly => _months(),
    GanttZoom.quarterly => _seasons(),
  };

  List<HeaderSegment> _years() {
    final out = <HeaderSegment>[];
    var offset = 0;
    while (offset < days) {
      final j = jalaliOf(dayAt(offset));
      final yearEnd =
          daysBetween(
            dayAt(offset),
            dayOf(Jalali(j.year, 12, Jalali(j.year, 12, 1).monthLength)),
          ) +
          1;
      final len = yearEnd.clamp(1, days - offset);
      out.add(HeaderSegment(toPersianDigits(j.year), offset, len));
      offset += len;
    }
    return out;
  }

  List<HeaderSegment> _seasons() {
    final out = <HeaderSegment>[];
    var offset = 0;
    while (offset < days) {
      final j = jalaliOf(dayAt(offset));
      final season = (j.month - 1) ~/ 3;
      final lastMonth = season * 3 + 3;
      final end = dayOf(
        Jalali(j.year, lastMonth, Jalali(j.year, lastMonth, 1).monthLength),
      );
      final len = (daysBetween(dayAt(offset), end) + 1).clamp(1, days - offset);
      out.add(HeaderSegment(_seasonNames[season], offset, len));
      offset += len;
    }
    return out;
  }
}
