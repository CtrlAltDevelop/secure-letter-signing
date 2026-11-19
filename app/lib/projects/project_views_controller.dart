import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:letter_signing/jalali/jalali_month.dart';
import 'package:letter_signing/projects/models.dart';
import 'package:letter_signing/projects/projects_env.dart';
import 'package:letter_signing/tasks/models.dart';
import 'package:letter_signing/workspace/workspace_api.dart'
    show NotFoundException;

/// Base for the three lazily loaded project views: one `load`, guarded against stale replies.
abstract class _ViewController extends ChangeNotifier {
  _ViewController(this.env, this.projectId);

  final ProjectsEnv env;
  final String projectId;

  bool _loading = false;
  bool _loaded = false;
  bool _disposed = false;
  Object? _error;
  int _generation = 0;

  bool get loading => _loading;
  bool get loaded => _loaded;
  Object? get error => _error;

  void notify() {
    if (!_disposed) notifyListeners();
  }

  /// Runs [fetch] and stores its result through [store]; ignores a reply that a newer load
  /// overtook.
  Future<void> run<T>(
    Future<T> Function() fetch,
    void Function(T value) store,
  ) async {
    final gen = ++_generation;
    _loading = true;
    _error = null;
    notify();
    try {
      final value = await fetch();
      if (gen != _generation) return;
      store(value);
    } on Object catch (e) {
      if (gen != _generation) return;
      _error = e;
    }
    _loading = false;
    _loaded = true;
    notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The flat list view with a search text and a status filter.
class ProjectListController extends _ViewController {
  ProjectListController(super.env, super.projectId);

  List<TaskBrief> _tasks = const [];
  String _query = '';
  String _status = '';

  List<TaskBrief> get tasks => _tasks;
  String get query => _query;
  String get status => _status;

  Future<void> load() => run(
    () => env.api.tasks(projectId, q: _query, status: _status),
    (v) => _tasks = v,
  );

  Future<void> setQuery(String query) {
    _query = query.trim();
    return load();
  }

  Future<void> setStatus(String status) {
    _status = status;
    return load();
  }
}

/// The Jalali month calendar: tasks of the shown month grouped by their due day.
class ProjectCalendarController extends _ViewController {
  ProjectCalendarController(super.env, super.projectId, {DateTime? today})
    : _month = JalaliMonth.of(today ?? DateTime.now()) {
    _selectedDay = _month.dayOf(today ?? DateTime.now());
  }

  JalaliMonth _month;
  int? _selectedDay;
  List<TaskBrief> _tasks = const [];

  JalaliMonth get month => _month;
  int? get selectedDay => _selectedDay;

  /// Tasks keyed by the Jalali day of the month they fall due on.
  Map<int, List<TaskBrief>> get byDay {
    final out = <int, List<TaskBrief>>{};
    for (final t in _tasks) {
      final due = t.dueAt;
      final day = due == null ? null : _month.dayOf(due);
      if (day != null) (out[day] ??= []).add(t);
    }
    return out;
  }

  List<TaskBrief> get selectedTasks => byDay[_selectedDay] ?? const [];

  Future<void> load() => run(
    () => env.api.tasks(
      projectId,
      view: 'calendar',
      from: _month.start,
      to: _month.end,
    ),
    (v) => _tasks = v,
  );

  Future<void> goTo(JalaliMonth month) {
    _month = month;
    _selectedDay = null;
    _tasks = const [];
    return load();
  }

  Future<void> shift(int months) => goTo(_month.shift(months));

  void select(int day) {
    _selectedDay = _selectedDay == day ? null : day;
    notify();
  }
}

/// Attachments of the project. [supported] turns false when the server has no endpoint.
class ProjectFilesController extends _ViewController {
  ProjectFilesController(super.env, super.projectId);

  List<ProjectFile> _files = const [];
  String _type = '';
  String _query = '';
  bool _supported = true;

  List<ProjectFile> get files => _files;
  String get type => _type;
  String get query => _query;
  bool get supported => _supported;

  Future<void> load() async {
    await run(() async {
      try {
        return await env.api.files(projectId, type: _type, q: _query);
      } on NotFoundException {
        _supported = false;
        return <ProjectFile>[];
      }
    }, (v) => _files = v);
  }

  Future<void> setType(String type) {
    _type = type;
    return load();
  }

  Future<void> setQuery(String query) {
    _query = query.trim();
    return load();
  }
}
