import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:letter_signing/letters/models.dart' show LiveEvent;
import 'package:letter_signing/projects/models.dart';
import 'package:letter_signing/projects/projects_env.dart';
import 'package:letter_signing/workspace/subject_controller.dart'
    show ActionOutcome, outcomeOf;

/// Projects of one group (or the ungrouped ones when [group] is null).
@immutable
class ProjectSection {
  const ProjectSection(this.group, this.projects);
  final ProjectGroup? group;
  final List<ProjectBrief> projects;
}

/// The project list: groups, status filter, search, collapsed groups, live refresh and the
/// group management calls.
class ProjectsController extends ChangeNotifier {
  ProjectsController({required this.env}) {
    _sub = env.live.events.listen((e) {
      if (e.isWorkspace && e.raw['module'] == 'projects') unawaited(refresh());
    });
  }

  final ProjectsEnv env;

  StreamSubscription<LiveEvent>? _sub;
  List<ProjectBrief> _projects = const [];
  List<ProjectGroup> _groups = const [];
  final Set<int> _collapsed = {};
  bool _loading = false;
  bool _loaded = false;
  bool _disposed = false;
  Object? _error;
  Object? _lastError;
  String _status = ProjectStatus.active;
  String _query = '';
  int _generation = 0;

  List<ProjectBrief> get projects => _projects;
  List<ProjectGroup> get groups => _groups;
  bool get loading => _loading;
  bool get loaded => _loaded;
  Object? get error => _error;
  Object? get lastError => _lastError;

  /// A status code or an empty string for every status.
  String get status => _status;
  String get query => _query;
  bool get filtered => _status != ProjectStatus.active || _query.isNotEmpty;

  bool isCollapsed(int groupId) => _collapsed.contains(groupId);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void toggleGroup(int groupId) {
    if (!_collapsed.remove(groupId)) _collapsed.add(groupId);
    _notify();
  }

  /// Groups in rank order with their projects, then the ungrouped projects last.
  List<ProjectSection> get sections {
    final known = {
      for (final g in _groups)
        if (g.active) g.id,
    };
    final sections = <ProjectSection>[
      for (final g in _groups)
        if (g.active)
          ProjectSection(g, [
            for (final p in _projects)
              if (p.groupId == g.id) p,
          ]),
    ];
    final loose = [
      for (final p in _projects)
        if (p.groupId == null || !known.contains(p.groupId)) p,
    ];
    return [
      for (final s in sections)
        if (s.projects.isNotEmpty || !filtered) s,
      if (loose.isNotEmpty) ProjectSection(null, loose),
    ];
  }

  Future<void> load() => _fetch(keep: false);

  Future<void> refresh() => _fetch(keep: true);

  Future<void> _fetch({required bool keep}) async {
    final gen = ++_generation;
    _loading = !keep || _projects.isEmpty;
    if (!keep) _error = null;
    _notify();
    try {
      final results = await Future.wait([
        env.api.list(status: _status, q: _query),
        env.api.groups(),
      ]);
      if (gen != _generation) return;
      _projects = results[0] as List<ProjectBrief>;
      _groups = results[1] as List<ProjectGroup>;
      _error = null;
    } on Object catch (e) {
      if (gen != _generation) return;
      _error = e;
    }
    _loading = false;
    _loaded = true;
    _notify();
  }

  Future<void> setStatus(String status) {
    if (status == _status) return Future.value();
    _status = status;
    return load();
  }

  Future<void> setQuery(String query) {
    final q = query.trim();
    if (q == _query) return Future.value();
    _query = q;
    return load();
  }

  Future<ActionOutcome> _groupAction(Future<Object?> Function() action) async {
    try {
      await action();
    } on Object catch (e) {
      _lastError = e;
      return outcomeOf(e);
    }
    await _reloadGroups();
    return ActionOutcome.ok;
  }

  /// Includes deactivated groups, so the management sheet can bring them back.
  Future<void> _reloadGroups() async {
    try {
      _groups = await env.api.groups(includeInactive: true);
    } on Object catch (e) {
      _lastError = e;
    }
    _notify();
  }

  /// Loads every group, deactivated ones too (for the management sheet).
  Future<void> loadAllGroups() => _reloadGroups();

  Future<ActionOutcome> createGroup(String name, {required String scope}) =>
      _groupAction(() => env.api.createGroup(name.trim(), scope: scope));

  Future<ActionOutcome> renameGroup(int id, String name) =>
      _groupAction(() => env.api.patchGroup(id, name: name.trim()));

  Future<ActionOutcome> setGroupActive(int id, {required bool active}) =>
      _groupAction(() => env.api.patchGroup(id, active: active));

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
