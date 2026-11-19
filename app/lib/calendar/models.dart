import 'package:flutter/foundation.dart';

import 'package:letter_signing/workspace/models.dart';

/// `CalendarItem`: `{kind, id, subject_id, title, start, end, all_day, status, project_id,
/// project_name, color, done, owner_ids}`; `owner_ids` is null outside the team view.
@immutable
class CalendarItem {
  const CalendarItem({
    required this.kind,
    required this.id,
    this.subjectId = '',
    this.title = '',
    required this.start,
    required this.end,
    this.allDay = false,
    this.status = '',
    this.projectId,
    this.projectName = '',
    this.color = 0,
    this.done = false,
    this.ownerIds,
  });

  final String kind;
  final String id;
  final String subjectId;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String status;
  final String? projectId;
  final String projectName;
  final int color;
  final bool done;
  final List<int>? ownerIds;

  static CalendarItem? tryParse(Map<String, dynamic> j) {
    final start = parseDate(j['start']);
    if (start == null) return null;
    return CalendarItem(
      kind: asString(j['kind']),
      id: asString(j['id']),
      subjectId: asString(j['subject_id']),
      title: asString(j['title']),
      start: start.toLocal(),
      end: (parseDate(j['end']) ?? start).toLocal(),
      allDay: j['all_day'] == true,
      status: asString(j['status']),
      projectId: j['project_id'] is String
          ? j['project_id'] as String
          : null, // ignore: use_null_aware_elements
      projectName: asString(j['project_name']),
      color: asInt(j['color']) ?? 0,
      done: j['done'] == true,
      ownerIds: j['owner_ids'] is List ? asIntList(j['owner_ids']) : null,
    );
  }

  /// Local calendar days the item covers; an all-day end is exclusive. Capped at 100 days.
  List<DateTime> get days {
    final first = DateTime(start.year, start.month, start.day);
    var last = DateTime(end.year, end.month, end.day);
    if (allDay && end.isAfter(start)) {
      last = last.subtract(const Duration(days: 1));
    }
    final out = <DateTime>[];
    var d = first;
    while (!d.isAfter(last) && out.length < 100) {
      out.add(d);
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return out.isEmpty ? [first] : out;
  }
}

/// `HolidayOut`: `{id, date, title, kind official|religious|company, active}`.
@immutable
class Holiday {
  const Holiday({required this.date, required this.title, this.kind = ''});
  final String date; // YYYY-MM-DD
  final String title;
  final String kind;

  factory Holiday.fromJson(Map<String, dynamic> j) => Holiday(
    date: asString(j['date']),
    title: asString(j['title']),
    kind: asString(j['kind']),
  );
}

/// `GET /calendar` answer.
@immutable
class CalendarData {
  const CalendarData({
    this.items = const [],
    this.holidays = const [],
    this.weekend = const [5],
  });
  final List<CalendarItem> items;
  final List<Holiday> holidays;
  final List<int> weekend;

  factory CalendarData.fromJson(Object? raw) {
    final j = asMap(raw);
    return CalendarData(
      items: [for (final e in asMapList(j['items'])) ?CalendarItem.tryParse(e)],
      holidays: [for (final e in asMapList(j['holidays'])) Holiday.fromJson(e)],
      weekend: j['weekend'] is List ? asIntList(j['weekend']) : const [5],
    );
  }
}

/// Filters of the calendar; `status` is applied on the device, the rest by the server.
@immutable
class CalendarFilter {
  const CalendarFilter({
    this.projectId,
    this.labelId,
    this.ownerId,
    this.customerId,
    this.status = CalendarStatus.all,
    this.team = false,
  });

  final String? projectId;
  final int? labelId;
  final int? ownerId;
  final String? customerId;
  final String status;
  final bool team;

  bool get isActive =>
      projectId != null ||
      labelId != null ||
      ownerId != null ||
      customerId != null ||
      status != CalendarStatus.all;

  CalendarFilter copyWith({
    Object? projectId = _keep,
    Object? labelId = _keep,
    Object? ownerId = _keep,
    Object? customerId = _keep,
    String? status,
    bool? team,
  }) => CalendarFilter(
    projectId: identical(projectId, _keep)
        ? this.projectId
        : projectId as String?,
    labelId: identical(labelId, _keep) ? this.labelId : labelId as int?,
    ownerId: identical(ownerId, _keep) ? this.ownerId : ownerId as int?,
    customerId: identical(customerId, _keep)
        ? this.customerId
        : customerId as String?,
    status: status ?? this.status,
    team: team ?? this.team,
  );

  static const _keep = Object();
}

class CalendarStatus {
  const CalendarStatus._();
  static const all = 'all';
  static const open = 'open';
  static const done = 'done';
}
