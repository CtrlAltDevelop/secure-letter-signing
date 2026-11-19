import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:letter_signing/crm/crm_api.dart';
import 'package:letter_signing/crm/models.dart';
import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/letters/models.dart' show LiveEvent;

const customerPageSize = 50;

/// A filtered, paged list of customer files; reloads on live `crm` events.
class CustomersController extends ChangeNotifier {
  CustomersController({
    required this.api,
    required this.live,
    CustomerFilter filter = const CustomerFilter(),
  }) {
    _filter = filter;
    _sub = live.events.listen((e) {
      if (e.isWorkspace && e.raw['module'] == 'crm') unawaited(load());
    });
  }

  final CrmApi api;
  final LiveService live;
  StreamSubscription<LiveEvent>? _sub;
  bool _disposed = false;
  List<Customer> _items = const [];
  late CustomerFilter _filter;
  bool _loading = true;
  bool _hasMore = false;
  Object? _error;

  List<Customer> get items => _items;
  CustomerFilter get filter => _filter;
  bool get loading => _loading;
  bool get hasMore => _hasMore;
  Object? get error => _error;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> setFilter(CustomerFilter filter) {
    _filter = filter;
    _loading = true;
    _notify();
    return load();
  }

  Future<void> load() async {
    try {
      final page = await api.list(_filter, limit: customerPageSize);
      _items = page;
      _hasMore = page.length == customerPageSize;
      _error = null;
    } on Object catch (e) {
      _error = e;
    }
    _loading = false;
    _notify();
  }

  Future<void> loadMore() async {
    if (!_hasMore || _loading) return;
    try {
      final page = await api.list(
        _filter,
        limit: customerPageSize,
        offset: _items.length,
      );
      _items = [..._items, ...page];
      _hasMore = page.length == customerPageSize;
    } on Object catch (e) {
      _error = e;
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
