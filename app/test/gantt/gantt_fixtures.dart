import 'package:http/http.dart' as http;
import 'package:letter_signing/gantt/gantt_api.dart';
import 'package:letter_signing/gantt/gantt_env.dart';
import 'package:letter_signing/gantt/gantt_models.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

import '../letters/fakes.dart';

/// Today at UTC midnight plus [days].
DateTime day(int days) => asDay(DateTime.now()).add(Duration(days: days));

Map<String, dynamic> itemJson(
  String id,
  String wbs,
  String title, {
  int level = 2,
  int? phase = 1,
  String? parent,
  int? start,
  int? end,
  int progress = 0,
}) => {
  'task_id': id,
  'wbs': wbs,
  'level': level,
  'title': title,
  'status': 'open',
  'progress': progress,
  'priority': 'normal',
  'weight': 1,
  'phase_id': phase,
  'parent_task_id': parent,
  'position': 0,
  'start_at': start == null ? null : dayString(day(start)),
  'end_at': end == null ? null : dayString(day(end)),
  'start': start == null ? null : dayString(day(start)),
  'end': end == null ? null : dayString(day(end)),
  'owners': [
    {'id': 2, 'full_name': 'Sara', 'email': 's@x.test'},
  ],
};

Map<String, dynamic> phaseJson(int id, String wbs, String title, {int? start, int? end}) => {
  'id': id,
  'wbs': wbs,
  'title': title,
  'position': id,
  'start_at': null,
  'end_at': null,
  'start': start == null ? null : dayString(day(start)),
  'end': end == null ? null : dayString(day(end)),
  'progress': 40,
  'task_count': 2,
  'active': true,
};

/// A chart: phase 1 "Design" with t1, t2 and a child t4 of t1; top-level t3; a conflicting
/// link t2 -> t1 reversed (t1 -> t2 fine), t1 -> t3 normal, and one unplanned task.
Map<String, dynamic> chartJson({bool canEdit = true}) => {
  'project_id': 'p1',
  'name': 'Alpha',
  'role': canEdit ? 'manager' : 'viewer',
  'can_edit': canEdit,
  'start': dayString(day(1)),
  'end': dayString(day(20)),
  'phases': [phaseJson(1, '1', 'Design', start: 1, end: 12)],
  'items': [
    itemJson('t1', '1.1', 'Draft', start: 1, end: 5, progress: 60),
    itemJson('t4', '1.1.1', 'Sketch', level: 3, parent: 't1', phase: null, start: 2, end: 3),
    itemJson('t2', '1.2', 'Review', start: 8, end: 12),
    itemJson('t3', '2', 'Ship', level: 1, phase: null, start: 15, end: 20),
  ],
  'links': [
    {'id': 11, 'predecessor_task_id': 't1', 'successor_task_id': 't2', 'kind': 'fs', 'conflict': false},
    {'id': 12, 'predecessor_task_id': 't3', 'successor_task_id': 't2', 'kind': 'fs', 'conflict': true},
  ],
  'unplanned': [
    {'task_id': 'u1', 'title': 'Loose task', 'status': 'open', 'progress': 0, 'start': null, 'end': null},
  ],
};

class FakeGanttServer {
  Map<String, dynamic> chart = chartJson();
  String? failDetail;
  final calls = <http.Request>[];
  final bodies = <Object?>[];

  Iterable<int> where(String method, String part) => [
    for (var i = 0; i < calls.length; i++)
      if (calls[i].method == method && calls[i].url.path.contains(part)) i,
  ];

  Object? lastBody(String method, String part) {
    final hits = where(method, part);
    return hits.isEmpty ? null : bodies[hits.last];
  }

  bool called(String method, String part) => where(method, part).isNotEmpty;

  http.Response handle(http.Request req, Object? body) {
    calls.add(req);
    bodies.add(body);
    final path = req.url.path.replaceFirst('/api', '');
    if (!path.startsWith('/projects/p1/gantt')) return json({'detail': 'nope'}, 404);
    final tail = path.substring('/projects/p1/gantt'.length);
    if (req.method != 'GET' && failDetail != null) {
      final d = failDetail!;
      failDetail = null;
      return json({'detail': d}, 422);
    }
    if (tail.isEmpty || tail == '/reorder') return json(chart);
    if (tail == '/print') {
      return json({
        'project_id': 'p1',
        'name': 'Alpha',
        'generated_at': '2026-01-01T00:00:00Z',
        'start': dayString(day(1)),
        'end': dayString(day(20)),
        'days': 20,
        'weekend': [6],
        'holidays': [
          {'date': dayString(day(3)), 'title': 'Holiday'},
        ],
        'progress': 35,
        'rows': [
          for (final p in (chart['phases'] as List))
            {'kind': 'phase', 'wbs': p['wbs'], 'level': 1, 'title': p['title'], 'status': '', 'progress': p['progress'], 'start': p['start'], 'end': p['end'], 'owners': <String>[]},
          for (final i in (chart['items'] as List))
            {'kind': 'task', 'wbs': i['wbs'], 'level': i['level'], 'title': i['title'], 'status': 'open', 'progress': i['progress'], 'start': i['start'], 'end': i['end'], 'owners': ['Sara']},
        ],
        'links': [
          {'from_wbs': '1.1', 'to_wbs': '1.2', 'conflict': false},
        ],
      });
    }
    if (tail.endsWith('/phases') || tail.contains('/phases/')) return json({...phaseJson(2, '2', 'New')}, 201);
    if (tail.contains('/items/')) return json(chart['items'][0]);
    if (tail.endsWith('/links')) return json({'id': 13, 'predecessor_task_id': 'a', 'successor_task_id': 'b', 'kind': 'fs', 'conflict': false}, 201);
    if (tail.contains('/deactivate')) return json({'detail': 'ok'});
    return json({'detail': 'unhandled $tail'}, 404);
  }
}

({FakeGanttServer server, GanttApi api, GanttEnv env}) ganttFixture({bool canEdit = true}) {
  final server = FakeGanttServer()..chart = chartJson(canEdit: canEdit);
  final f = fakeApi(server.handle);
  final api = GanttApi(WorkspaceApi(f.client));
  return (server: server, api: api, env: GanttEnv(api: api));
}
