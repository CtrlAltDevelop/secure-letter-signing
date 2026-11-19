import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// Reporting window: a rolling preset (`week|month|quarter|year`) or a custom range, plus the
/// bucket size of the overview series. Month buckets are always Jalali.
class MonitorPeriod {
  const MonitorPeriod({
    this.preset = 'month',
    this.from,
    this.to,
    this.bucket = 'day',
  });

  final String preset;
  final DateTime? from;
  final DateTime? to;
  final String bucket;

  bool get custom => from != null && to != null;

  MonitorPeriod copyWith({
    String? preset,
    DateTime? from,
    DateTime? to,
    String? bucket,
  }) => MonitorPeriod(
    preset: preset ?? this.preset,
    from: preset != null ? null : (from ?? this.from),
    to: preset != null ? null : (to ?? this.to),
    bucket: bucket ?? this.bucket,
  );

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, Object?> query() => {
    if (custom) ...{'from': _day(from!), 'to': _day(to!)} else 'period': preset,
    'calendar': 'jalali',
    'bucket': bucket,
  };
}

/// Typed access to `/monitor/*`. `GET /monitor/me` is open to everyone; every other call is a
/// [NotFoundException] for users without `monitor.view` (or when the module is off).
class MonitorApi {
  MonitorApi(this.workspace);

  final WorkspaceApi workspace;

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, Object?> q,
  ) async => asMap(
    await workspace.call('GET', '/monitor/$path${WorkspaceApi.query(q)}'),
  );

  Future<Map<String, dynamic>> me() => _get('me', const {});

  Future<Map<String, dynamic>> overview(MonitorPeriod p) =>
      _get('overview', p.query());

  Future<Map<String, dynamic>> projects(String sort) =>
      _get('projects', {'sort': sort});

  Future<Map<String, dynamic>> tasks({
    String project = '',
    int? label,
    int? person,
    String customer = '',
    bool printable = false,
  }) => _get('tasks', {
    'project': project,
    'label': label,
    'person': person,
    'customer': customer,
    'printable': printable ? 'true' : null,
  });

  Future<Map<String, dynamic>> meetings(
    MonitorPeriod p, {
    String project = '',
  }) => _get('meetings', {...p.query(), 'project': project});

  Future<Map<String, dynamic>> members(MonitorPeriod p, String sort) =>
      _get('members', {...p.query(), 'sort': sort});

  Future<Map<String, dynamic>> online({int? historyOf}) =>
      _get('online', {'history_of': historyOf});

  Future<Map<String, dynamic>> customers(MonitorPeriod p) =>
      _get('customers', p.query());

  Future<Map<String, dynamic>> finance(MonitorPeriod p) =>
      _get('finance', p.query());

  Future<Map<String, dynamic>> sales() => _get('sales', const {});

  /// True when the caller may use [path] (`finance`, `sales`): a 404 hides the tab.
  Future<bool> available(String path) async {
    try {
      await _get(path, const {});
      return true;
    } on NotFoundException {
      return false;
    }
  }

  /// A colleague's active tasks (`monitor.view`): `[{id, title, status, due_at, ...}]`.
  Future<List<Map<String, dynamic>>> tasksOf(
    int userId, {
    String box = 'inbox',
  }) async => asMapList(
    await workspace.call(
      'GET',
      '/tasks/of/$userId${WorkspaceApi.query({'box': box, 'limit': 100})}',
    ),
  );

  /// Manager only: adds or changes members (`role`: manager|member|viewer) and removes users.
  Future<void> setGroupAccess(
    int groupId, {
    List<({int userId, String role})> add = const [],
    List<int> remove = const [],
  }) async {
    await workspace.call(
      'PUT',
      '/project-groups/$groupId/access',
      body: {
        'add': [
          for (final a in add) {'user_id': a.userId, 'role': a.role},
        ],
        'remove': remove,
      },
    );
  }
}
