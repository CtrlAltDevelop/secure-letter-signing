import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/letters/models.dart' show LiveEvent;
import 'package:letter_signing/sales/models.dart';
import 'package:letter_signing/sales/sales_api.dart';

/// A filtered list of leads; reloads on live `sales` events.
class SalesController extends ChangeNotifier {
  SalesController({
    required this.api,
    required this.live,
    LeadFilter filter = const LeadFilter(),
  }) {
    _filter = filter;
    _sub = live.events.listen((e) {
      if (e.isWorkspace && e.raw['module'] == 'sales') unawaited(load());
    });
  }

  final SalesApi api;
  final LiveService live;
  StreamSubscription<LiveEvent>? _sub;
  bool _disposed = false;
  List<Lead> _items = const [];
  late LeadFilter _filter;
  bool _loading = true;
  Object? _error;

  List<Lead> get items => _items;
  LeadFilter get filter => _filter;
  bool get loading => _loading;
  Object? get error => _error;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> setFilter(LeadFilter filter) {
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

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
