import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:letter_signing/search/models.dart';
import 'package:letter_signing/search/search_api.dart';

/// Debounced unified search: stale replies are dropped, short queries clear the result.
class UnifiedSearchController extends ChangeNotifier {
  UnifiedSearchController(
    this.api, {
    this.debounce = const Duration(milliseconds: 350),
  });

  final SearchApi api;
  final Duration debounce;

  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;
  String _query = '';
  Set<String> _modules = const {};
  List<SearchGroup> _groups = const [];
  bool _loading = false;
  Object? _error;

  String get query => _query;
  Set<String> get modules => _modules;
  List<SearchGroup> get groups => _groups;
  bool get loading => _loading;
  Object? get error => _error;
  bool get tooShort => _query.trim().length < SearchApi.minQuery;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Called on every keystroke.
  void setQuery(String value) {
    _query = value;
    _timer?.cancel();
    if (tooShort) {
      _generation++;
      _groups = const [];
      _loading = false;
      _error = null;
      _notify();
      return;
    }
    _timer = Timer(debounce, () => unawaited(run()));
  }

  void toggleModule(String module) {
    _modules = _modules.contains(module)
        ? {..._modules}.difference({module})
        : {..._modules, module};
    _notify();
    if (!tooShort) unawaited(run());
  }

  Future<void> run() async {
    final gen = ++_generation;
    _loading = true;
    _error = null;
    _notify();
    try {
      final hits = await api.search(_query.trim(), modules: [..._modules]);
      if (gen != _generation) return;
      _groups = groupHits(hits);
    } on Object catch (e) {
      if (gen != _generation) return;
      _groups = const [];
      _error = e;
    }
    _loading = false;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
