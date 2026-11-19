import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/letters/models.dart' show LiveEvent;
import 'package:letter_signing/meetings/meetings_api.dart';
import 'package:letter_signing/meetings/models.dart';

const _pageSize = 50;

/// Upcoming meetings first (soonest first), then the rest newest first; undated ones last.
List<MeetingBrief> sortUpcomingFirst(
  Iterable<MeetingBrief> rows, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final upcoming = <MeetingBrief>[];
  final past = <MeetingBrief>[];
  final undated = <MeetingBrief>[];
  for (final m in rows) {
    final start = m.startsAt;
    if (start == null) {
      undated.add(m);
    } else if (!start.isBefore(at)) {
      upcoming.add(m);
    } else {
      past.add(m);
    }
  }
  upcoming.sort((a, b) => a.startsAt!.compareTo(b.startsAt!));
  past.sort((a, b) => b.startsAt!.compareTo(a.startsAt!));
  return [...upcoming, ...past, ...undated];
}

/// The meetings list: filters, paging and live refresh.
class MeetingsController extends ChangeNotifier {
  MeetingsController({required this.api, required this.live}) {
    _sub = live.events.listen((e) {
      if (e.isWorkspace && e.raw['module'] == 'meetings') {
        unawaited(load());
      }
    });
  }

  final MeetingsApi api;
  final LiveService live;
  StreamSubscription<LiveEvent>? _sub;
  bool _disposed = false;

  List<MeetingBrief> _items = const [];
  MeetingFilter _filter = const MeetingFilter();
  bool _loading = true;
  bool _hasMore = false;
  Object? _error;

  List<MeetingBrief> get items => _items;
  MeetingFilter get filter => _filter;
  bool get loading => _loading;
  bool get hasMore => _hasMore;
  Object? get error => _error;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Replaces the filter and reloads from the first page.
  Future<void> setFilter(MeetingFilter filter) {
    _filter = filter;
    _loading = true;
    _notify();
    return load();
  }

  Future<void> load() async {
    try {
      final rows = await api.list(_filter, limit: _pageSize);
      _items = sortUpcomingFirst(rows);
      _hasMore = rows.length >= _pageSize;
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
      final rows = await api.list(
        _filter,
        limit: _pageSize,
        offset: _items.length,
      );
      _items = sortUpcomingFirst([..._items, ...rows]);
      _hasMore = rows.length >= _pageSize;
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
