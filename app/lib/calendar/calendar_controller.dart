import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:letter_signing/calendar/calendar_env.dart';
import 'package:letter_signing/calendar/models.dart';
import 'package:letter_signing/jalali/jalali_month.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Jalali month or week of the work calendar, with filters. A reply that a newer load
/// overtook is dropped.
class CalendarController extends ChangeNotifier {
  CalendarController(
    this.env, {
    CalendarFilter filter = const CalendarFilter(),
    DateTime? today,
  }) : _filter = filter, // ignore: prefer_initializing_formals
       _focus = _day(today ?? DateTime.now()),
       _selected = _day(today ?? DateTime.now());

  final CalendarEnv env;

  CalendarFilter _filter;
  DateTime _focus;
  DateTime _selected;
  bool _week = false;
  CalendarData _data = const CalendarData();
  bool _loading = false;
  bool _loaded = false;
  bool _disposed = false;
  Object? _error;
  int _generation = 0;

  CalendarFilter get filter => _filter;
  bool get week => _week;
  DateTime get selected => _selected;
  bool get loading => _loading;
  bool get loaded => _loaded;
  Object? get error => _error;
  JalaliMonth get month => JalaliMonth.of(_focus);
  List<Holiday> get holidays => _data.holidays;
  List<int> get weekend => _data.weekend;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Saturday of the week containing [_focus].
  DateTime get weekStart {
    final back = (_focus.weekday + 1) % 7; // Saturday = 0
    return DateTime(_focus.year, _focus.month, _focus.day - back);
  }

  /// First day (inclusive) and last day (exclusive) loaded.
  (DateTime, DateTime) get range => _week
      ? (
          weekStart,
          DateTime(weekStart.year, weekStart.month, weekStart.day + 7),
        )
      : (month.start, month.end);

  /// Items after the on-device status filter.
  List<CalendarItem> get items => [
    for (final i in _data.items)
      if (_filter.status == CalendarStatus.all ||
          (_filter.status == CalendarStatus.done) == i.done)
        i,
  ];

  Map<String, List<CalendarItem>> get byDay {
    final out = <String, List<CalendarItem>>{};
    for (final i in items) {
      for (final d in i.days) {
        (out[dayKey(d)] ??= []).add(i);
      }
    }
    return out;
  }

  Map<String, List<Holiday>> get holidaysByDay {
    final out = <String, List<Holiday>>{};
    for (final h in _data.holidays) {
      (out[h.date] ??= []).add(h);
    }
    return out;
  }

  List<CalendarItem> get selectedItems => byDay[dayKey(_selected)] ?? const [];
  List<Holiday> get selectedHolidays =>
      holidaysByDay[dayKey(_selected)] ?? const [];

  Future<void> load() async {
    final gen = ++_generation;
    _loading = true;
    _error = null;
    _notify();
    final (from, to) = range;
    try {
      final data = await env.api.calendar(from, to, filter: _filter);
      if (gen != _generation) return;
      _data = data;
    } on Object catch (e) {
      if (gen != _generation) return;
      _error = e;
    }
    _loading = false;
    _loaded = true;
    _notify();
  }

  Future<void> setFilter(CalendarFilter filter) {
    _filter = filter;
    return load();
  }

  Future<void> setWeek({required bool week}) {
    _week = week;
    _focus = _selected;
    return load();
  }

  /// Moves one month, or one week in week view.
  Future<void> shift(int step) {
    if (_week) {
      _focus = DateTime(_focus.year, _focus.month, _focus.day + 7 * step);
    } else {
      _focus = month.shift(step).start;
    }
    _selected = _focus;
    return load();
  }

  void select(DateTime day) {
    _selected = _day(day);
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
