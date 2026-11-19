import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:letter_signing/finance/finance_api.dart';
import 'package:letter_signing/finance/models.dart';
import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/letters/models.dart' show LiveEvent;
import 'package:letter_signing/workspace/subject_controller.dart'
    show ActionOutcome, outcomeOf;

/// A filtered list of finance documents; reloads on live `finance` events.
class FinanceController extends ChangeNotifier {
  FinanceController({
    required this.api,
    required this.live,
    FinanceFilter filter = const FinanceFilter(),
  }) {
    _filter = filter;
    _sub = live.events.listen((e) {
      if (e.isWorkspace && e.raw['module'] == 'finance') unawaited(load());
    });
  }

  final FinanceApi api;
  final LiveService live;
  StreamSubscription<LiveEvent>? _sub;
  bool _disposed = false;
  List<FinanceDoc> _items = const [];
  late FinanceFilter _filter;
  bool _loading = true;
  Object? _error;

  List<FinanceDoc> get items => _items;
  FinanceFilter get filter => _filter;
  bool get loading => _loading;
  Object? get error => _error;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> setFilter(FinanceFilter filter) {
    _filter = filter;
    _loading = true;
    _notify();
    return load();
  }

  Future<void> load() async {
    try {
      _items = await api.list(_filter);
      _error = null;
    } on Object catch (e) {
      _error = e;
    }
    _loading = false;
    _notify();
  }

  Future<ActionOutcome> confirm(FinanceDoc d) => _act(() => api.confirm(d.id));

  Future<ActionOutcome> voidDoc(FinanceDoc d, String reason) =>
      _act(() => api.voidDoc(d.id, reason));

  Future<ActionOutcome> _act(Future<Object?> Function() action) async {
    try {
      await action();
    } on Object catch (e) {
      _error = e;
      return outcomeOf(e);
    }
    await load();
    return ActionOutcome.ok;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
