import 'package:flutter/foundation.dart';

import 'package:letter_signing/workspace/models.dart';

/// A calendar day without a time zone: UTC midnight, so day arithmetic never meets DST.
DateTime? parseDay(Object? v) {
  if (v is! String || v.length < 10) return null;
  final d = DateTime.tryParse(v.substring(0, 10));
  return d == null ? null : DateTime.utc(d.year, d.month, d.day);
}

/// The wire form `YYYY-MM-DD` of a day (its y/m/d fields, whatever the zone).
String dayString(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Normalises any [DateTime] to a [parseDay]-style day.
DateTime asDay(DateTime d) => DateTime.utc(d.year, d.month, d.day);

int daysBetween(DateTime from, DateTime to) =>
    asDay(to).difference(asDay(from)).inDays;

@immutable
class GanttPhase {
  const GanttPhase({
    required this.id,
    required this.wbs,
    required this.title,
    required this.position,
    this.startAt,
    this.endAt,
    this.start,
    this.end,
    this.progress = 0,
    this.taskCount = 0,
    this.active = true,
  });

  final int id;
  final String wbs;
  final String title;
  final int position;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime? start;
  final DateTime? end;
  final int progress;
  final int taskCount;
  final bool active;

  factory GanttPhase.fromJson(Map<String, dynamic> j) => GanttPhase(
    id: (j['id'] as num).toInt(),
    wbs: asString(j['wbs']),
    title: asString(j['title']),
    position: (j['position'] as num?)?.toInt() ?? 0,
    startAt: parseDay(j['start_at']),
    endAt: parseDay(j['end_at']),
    start: parseDay(j['start']),
    end: parseDay(j['end']),
    progress: (j['progress'] as num?)?.toInt() ?? 0,
    taskCount: (j['task_count'] as num?)?.toInt() ?? 0,
    active: j['active'] != false,
  );
}

@immutable
class GanttItem {
  const GanttItem({
    required this.taskId,
    required this.wbs,
    required this.level,
    required this.title,
    required this.status,
    required this.progress,
    this.priority = '',
    this.weight = 1,
    this.phaseId,
    this.parentTaskId,
    this.position = 0,
    this.startAt,
    this.endAt,
    this.start,
    this.end,
    this.owners = const [],
    this.critical = false,
  });

  final String taskId;
  final String wbs;
  final int level;
  final String title;
  final String status;
  final int progress;
  final String priority;
  final int weight;
  final int? phaseId;
  final String? parentTaskId;
  final int position;
  final DateTime? startAt;
  final DateTime? endAt;

  /// Effective dates (plan date, else the task's own start / due date).
  final DateTime? start;
  final DateTime? end;
  final List<String> owners;

  /// On the longest finish-to-start chain (older servers omit it: false).
  final bool critical;

  bool get hasBar => start != null && end != null;

  factory GanttItem.fromJson(Map<String, dynamic> j) => GanttItem(
    taskId: asString(j['task_id']),
    wbs: asString(j['wbs']),
    level: (j['level'] as num?)?.toInt() ?? 1,
    title: asString(j['title']),
    status: asString(j['status']),
    progress: (j['progress'] as num?)?.toInt() ?? 0,
    priority: asString(j['priority']),
    weight: (j['weight'] as num?)?.toInt() ?? 1,
    phaseId: (j['phase_id'] as num?)?.toInt(),
    parentTaskId: j['parent_task_id'] as String?,
    position: (j['position'] as num?)?.toInt() ?? 0,
    startAt: parseDay(j['start_at']),
    endAt: parseDay(j['end_at']),
    start: parseDay(j['start']),
    end: parseDay(j['end']),
    owners: [
      for (final o in asMapList(j['owners']))
        asString(o['full_name']).isNotEmpty
            ? asString(o['full_name'])
            : asString(o['email']),
    ],
    critical: j['critical'] == true,
  );
}

@immutable
class GanttLink {
  const GanttLink({
    required this.id,
    required this.predecessorId,
    required this.successorId,
    this.conflict = false,
  });

  final int id;
  final String predecessorId;
  final String successorId;

  /// The successor is planned to start before the predecessor ends.
  final bool conflict;

  factory GanttLink.fromJson(Map<String, dynamic> j) => GanttLink(
    id: (j['id'] as num).toInt(),
    predecessorId: asString(j['predecessor_task_id']),
    successorId: asString(j['successor_task_id']),
    conflict: j['conflict'] == true,
  );
}

@immutable
class GanttUnplanned {
  const GanttUnplanned({
    required this.taskId,
    required this.title,
    required this.status,
    this.progress = 0,
    this.start,
    this.end,
  });

  final String taskId;
  final String title;
  final String status;
  final int progress;
  final DateTime? start;
  final DateTime? end;

  factory GanttUnplanned.fromJson(Map<String, dynamic> j) => GanttUnplanned(
    taskId: asString(j['task_id']),
    title: asString(j['title']),
    status: asString(j['status']),
    progress: (j['progress'] as num?)?.toInt() ?? 0,
    start: parseDay(j['start']),
    end: parseDay(j['end']),
  );
}

@immutable
class GanttChart {
  const GanttChart({
    required this.projectId,
    required this.name,
    required this.role,
    required this.canEdit,
    this.start,
    this.end,
    this.phases = const [],
    this.items = const [],
    this.links = const [],
    this.unplanned = const [],
  });

  final String projectId;
  final String name;
  final String role;
  final bool canEdit;
  final DateTime? start;
  final DateTime? end;
  final List<GanttPhase> phases;

  /// WBS order, phases interleaved by [rows].
  final List<GanttItem> items;
  final List<GanttLink> links;
  final List<GanttUnplanned> unplanned;

  factory GanttChart.fromJson(Map<String, dynamic> j) => GanttChart(
    projectId: asString(j['project_id']),
    name: asString(j['name']),
    role: asString(j['role']),
    canEdit: j['can_edit'] == true,
    start: parseDay(j['start']),
    end: parseDay(j['end']),
    phases: [for (final p in asMapList(j['phases'])) GanttPhase.fromJson(p)],
    items: [for (final i in asMapList(j['items'])) GanttItem.fromJson(i)],
    links: [for (final l in asMapList(j['links'])) GanttLink.fromJson(l)],
    unplanned: [
      for (final u in asMapList(j['unplanned'])) GanttUnplanned.fromJson(u),
    ],
  );

  GanttItem? item(String taskId) =>
      items.where((i) => i.taskId == taskId).firstOrNull;
  GanttPhase? phase(int id) => phases.where((p) => p.id == id).firstOrNull;
}

/// One line of the WBS tree: a phase or a task.
@immutable
class GanttRow {
  const GanttRow.phase(GanttPhase this.phase) : item = null;
  const GanttRow.task(GanttItem this.item) : phase = null;

  final GanttPhase? phase;
  final GanttItem? item;

  bool get isPhase => phase != null;
  String get wbs => phase?.wbs ?? item!.wbs;
  String get title => phase?.title ?? item!.title;
  int get progress => phase?.progress ?? item!.progress;
  DateTime? get start => phase?.start ?? item?.start;
  DateTime? get end => phase?.end ?? item?.end;
  int get level => isPhase ? 1 : item!.level;
  bool get critical => item?.critical ?? false;
  String get key => isPhase ? 'p${phase!.id}' : item!.taskId;
}

/// Phases and tasks merged in WBS order (`1`, `1.1`, `1.2`, `2`, ...).
List<GanttRow> chartRows(GanttChart chart) {
  int cmp(String a, String b) {
    final x = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final y = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < x.length && i < y.length; i++) {
      if (x[i] != y[i]) return x[i].compareTo(y[i]);
    }
    return x.length.compareTo(y.length);
  }

  final rows = [
    for (final p in chart.phases)
      if (p.active) GanttRow.phase(p),
    for (final i in chart.items) GanttRow.task(i),
  ]..sort((a, b) => cmp(a.wbs, b.wbs));
  return rows;
}

/// `GET .../print`: holidays and weekend of the chart range, and flat rows.
@immutable
class GanttCalendarMarks {
  const GanttCalendarMarks({
    this.weekend = const [6],
    this.holidays = const {},
  });

  /// 0 = Saturday .. 6 = Friday.
  final List<int> weekend;
  final Map<DateTime, String> holidays;

  bool isWeekend(DateTime d) => weekend.contains((d.weekday + 1) % 7);
  bool isHoliday(DateTime d) => holidays.containsKey(asDay(d));
}

@immutable
class GanttPrintRow {
  const GanttPrintRow({
    required this.kind,
    required this.wbs,
    required this.level,
    required this.title,
    required this.progress,
    this.start,
    this.end,
    this.owners = const [],
    this.critical = false,
  });

  final String kind;
  final String wbs;
  final int level;
  final String title;
  final int progress;
  final DateTime? start;
  final DateTime? end;
  final List<String> owners;
  final bool critical;

  bool get isPhase => kind == 'phase';

  factory GanttPrintRow.fromJson(Map<String, dynamic> j) => GanttPrintRow(
    kind: asString(j['kind']),
    wbs: asString(j['wbs']),
    level: (j['level'] as num?)?.toInt() ?? 1,
    title: asString(j['title']),
    progress: (j['progress'] as num?)?.toInt() ?? 0,
    start: parseDay(j['start']),
    end: parseDay(j['end']),
    owners: [for (final o in (j['owners'] as List? ?? const [])) '$o'],
    critical: j['critical'] == true,
  );
}

@immutable
class GanttPrint {
  const GanttPrint({
    required this.name,
    this.start,
    this.end,
    this.days = 0,
    this.progress = 0,
    this.rows = const [],
    this.links = const [],
    this.marks = const GanttCalendarMarks(),
  });

  final String name;
  final DateTime? start;
  final DateTime? end;
  final int days;
  final int progress;
  final List<GanttPrintRow> rows;

  /// `(from_wbs, to_wbs, conflict)`.
  final List<(String, String, bool)> links;
  final GanttCalendarMarks marks;

  factory GanttPrint.fromJson(Map<String, dynamic> j) => GanttPrint(
    name: asString(j['name']),
    start: parseDay(j['start']),
    end: parseDay(j['end']),
    days: (j['days'] as num?)?.toInt() ?? 0,
    progress: (j['progress'] as num?)?.toInt() ?? 0,
    rows: [for (final r in asMapList(j['rows'])) GanttPrintRow.fromJson(r)],
    links: [
      for (final l in asMapList(j['links']))
        (asString(l['from_wbs']), asString(l['to_wbs']), l['conflict'] == true),
    ],
    marks: marksOf(j),
  );

  static GanttCalendarMarks marksOf(Map<String, dynamic> j) =>
      GanttCalendarMarks(
        weekend: [
          for (final w in (j['weekend'] as List? ?? const [6]))
            (w as num).toInt(),
        ],
        holidays: {
          for (final h in asMapList(j['holidays']))
            if (parseDay(h['date']) != null)
              parseDay(h['date'])!: asString(h['title']),
        },
      );
}
