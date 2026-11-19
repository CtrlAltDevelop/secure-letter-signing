import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/letters/models.dart' show LiveEvent;
import 'package:letter_signing/tasks/models.dart';
import 'package:letter_signing/tasks/tasks_api.dart';

/// Which slice of tasks a list shows (`box` of `GET /tasks`).
class TaskBox {
  const TaskBox._();
  static const inbox = 'inbox';
  static const followup = 'followup';
  static const all = 'all';
  static const values = [inbox, followup, all];
}

/// One task list (a box plus its filters): first page, paging, pull-to-refresh and live
/// refresh when a workspace task event arrives.
class TasksListController extends ChangeNotifier {
  TasksListController({
    required this.api,
    required this.live,
    required this.box,
    this.pageSize = 50,
  }) {
    _sub = live.events.listen((e) {
      if (e.isWorkspace && e.raw['module'] == 'tasks') unawaited(refresh());
    });
  }

  final TasksApi api;
  final LiveService live;
  final String box;
  final int pageSize;

  StreamSubscription<LiveEvent>? _sub;
  List<TaskBrief> _items = const [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _loaded = false;
  bool _disposed = false;
  Object? _error;
  String _status = '';
  String _query = '';
  int? _labelId;
  String? _customerId;
  String _customerName = '';
  int _generation = 0;

  List<TaskBrief> get items => _items;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  bool get loaded => _loaded;
  Object? get error => _error;
  String get status => _status;
  String get query => _query;
  int? get labelId => _labelId;
  String? get customerId => _customerId;
  String get customerName => _customerName;
  bool get filtered =>
      _status.isNotEmpty ||
      _query.isNotEmpty ||
      _labelId != null ||
      _customerId != null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Loads the first page (showing the loading state when nothing is shown yet).
  Future<void> load() => _fetch(keep: false);

  /// Reloads what is shown without flicker: as many rows as are loaded, at least a page.
  Future<void> refresh() => _fetch(keep: true);

  Future<void> _fetch({required bool keep}) async {
    final gen = ++_generation;
    _loadingMore = false;
    _loading = !keep || _items.isEmpty;
    if (!keep) _error = null;
    _notify();
    final want = keep && _items.length > pageSize ? _items.length : pageSize;
    try {
      final rows = await _page(offset: 0, limit: want);
      if (gen != _generation) return;
      _items = rows;
      _hasMore = rows.length >= want;
      _error = null;
    } on Object catch (e) {
      if (gen != _generation) return;
      _error = e;
    }
    _loading = false;
    _loaded = true;
    _notify();
  }

  /// Appends the next page; ignored while loading or when everything is shown.
  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_hasMore || _error != null) return;
    final gen = _generation;
    _loadingMore = true;
    _notify();
    try {
      final rows = await _page(offset: _items.length, limit: pageSize);
      if (gen != _generation) return;
      _items = [..._items, ...rows];
      _hasMore = rows.length >= pageSize;
    } on Object catch (e) {
      if (gen != _generation) return;
      _error = e;
    }
    _loadingMore = false;
    _notify();
  }

  Future<List<TaskBrief>> _page({required int offset, required int limit}) =>
      api.list(
        box: box,
        status: _status,
        q: _query,
        label: _labelId,
        customer: _customerId,
        limit: limit,
        offset: offset,
      );

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

  Future<void> setLabel(int? labelId) {
    if (labelId == _labelId) return Future.value();
    _labelId = labelId;
    return load();
  }

  /// Filters by a customer file ([id] null clears it); [name] is only for the chip.
  Future<void> setCustomer(String? id, {String name = ''}) {
    if (id == _customerId) return Future.value();
    _customerId = id;
    _customerName = id == null ? '' : name;
    return load();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
