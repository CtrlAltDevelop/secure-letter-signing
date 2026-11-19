import 'package:http/http.dart' as http;
import 'package:letter_signing/monitor/monitor_api.dart';
import 'package:letter_signing/monitor/monitor_env.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

import '../letters/fakes.dart';

List<Map<String, dynamic>> series(List<int> v) => [
  for (final (i, n) in v.indexed) {'date': '2026-01-0${i + 1}', 'value': n},
];

/// A scripted `/monitor/*` server; every request is recorded. [hide] paths answer 404.
class FakeMonitorServer {
  FakeMonitorServer({this.hide = const {}});

  final Set<String> hide;
  final List<http.Request> calls = [];
  final List<Object?> bodies = [];

  Iterable<http.Request> where(String method, String part) =>
      calls.where((r) => r.method == method && r.url.path.contains(part));

  http.Response handle(http.Request req, Object? body) {
    calls.add(req);
    bodies.add(body);
    final path = req.url.path.replaceFirst('/api', '');
    if (hide.any(path.startsWith)) return json({'detail': 'Not found'}, 404);
    if (path == '/monitor/me') {
      return json({
        'tasks': {'open': 5, 'overdue': 2, 'done_in_period': 7},
        'letters': {'waiting': 3},
        'meetings_today': 1,
        'unread_chat': 9,
      });
    }
    if (path == '/monitor/overview') {
      return json({
        'modules': {
          'chat': {
            'series': {
              'messages': series([1, 4, 2]),
            },
          },
          'tasks': {
            'series': {
              'created': series([2, 2]),
              'completed': series([1]),
              'overdue': series([0]),
            },
          },
        },
      });
    }
    if (path == '/monitor/projects') {
      return json({
        'projects': [
          {
            'id': 'p1',
            'name': 'Alpha',
            'group_name': 'G',
            'tasks_open': 1,
            'tasks_done': 2,
            'tasks_overdue': 3,
          },
        ],
        'groups': [
          {
            'group_id': 1,
            'group_name': 'Group One',
            'projects': 1,
            'tasks_open': 1,
            'tasks_done': 2,
            'tasks_overdue': 3,
          },
        ],
      });
    }
    if (path == '/monitor/tasks') {
      return json({
        'by_status': {
          'open': 4,
          'awaiting_approval': 1,
          'done': 8,
          'cancelled': 0,
        },
        'overdue_total': 1,
        'overdue': [
          {
            'id': 't1',
            'title': 'Late task',
            'days_late': 4,
            'project_name': 'Alpha',
            'owners': [
              {'id': 2, 'full_name': 'Sara', 'email': 's@x'},
            ],
          },
        ],
      });
    }
    if (path == '/monitor/meetings') {
      return json({
        'total': 1,
        'by_status': {'held': 1},
        'meetings': [
          {
            'id': 'm1',
            'title': 'Board',
            'starts_at': '2026-01-02T08:00:00Z',
            'project_name': 'Alpha',
            'invited': 5,
            'present': 4,
            'open_resolutions': 1,
          },
        ],
      });
    }
    if (path == '/monitor/members') {
      return json({
        'members': [
          {
            'user': {'id': 2, 'full_name': 'Sara', 'email': 's@x'},
            'tasks': {
              'on_time': 6,
              'late': 1,
              'overdue': 2,
              'avg_delay_days': 1.5,
            },
            'messages': 10,
          },
        ],
      });
    }
    if (path == '/monitor/online') {
      return json({
        'users': [
          {
            'user': {'id': 2, 'full_name': 'Sara', 'email': 's@x'},
            'last_active': '2026-01-02T08:00:00Z',
            'online': true,
          },
        ],
        if (req.url.queryParameters['history_of'] != null)
          'history': [
            {
              'device_name': 'Pixel',
              'platform': 'android',
              'created_at': '2026-01-01T08:00:00Z',
              'last_active': '2026-01-02T08:00:00Z',
              'revoked': false,
            },
          ],
      });
    }
    if (path == '/monitor/customers') {
      return json({
        'total': 3,
        'quiet': 2,
        'created_in_period': 1,
        'by_status': {'active': 3},
        'customers': [
          {
            'id': 'c1',
            'name': 'Acme',
            'last_event_at': null,
            'open_tasks': 1,
            'overdue_tasks': 0,
          },
        ],
      });
    }
    if (path == '/monitor/finance') {
      return json({
        'totals': {'net': 100},
        'buckets': [
          {'period': '1404-10', 'net': 100},
        ],
      });
    }
    if (path == '/monitor/sales') {
      return json({
        'by_status': {'open': 2, 'won': 1, 'lost': 0},
        'won_by_month': <Object>[],
      });
    }
    if (path.startsWith('/tasks/of/')) {
      return json([
        {'id': 't9', 'title': 'Their task', 'due_at': null},
      ]);
    }
    if (path.startsWith('/project-groups/') && path.endsWith('/access')) {
      return json({'ok': true});
    }
    if (path == '/labels') return json(<Object>[]);
    return json(<Object>[]);
  }
}

MonitorEnv monitorEnv(
  FakeMonitorServer s, {
  bool canMonitor = true,
  bool Function(String)? enabled,
}) {
  final f = fakeApi(s.handle);
  return MonitorEnv(
    api: MonitorApi(WorkspaceApi(f.client, httpClient: f.api.httpClient)),
    canMonitor: canMonitor,
    isEnabled: enabled ?? (_) => true,
    directory: () async => [const UserRef(id: 2, fullName: 'Sara')],
  );
}
