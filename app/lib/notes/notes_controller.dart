import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/letters/models.dart' show LiveEvent;
import 'package:letter_signing/notes/models.dart';
import 'package:letter_signing/notes/notes_api.dart';
import 'package:letter_signing/workspace/subject_controller.dart'
    show ActionOutcome, outcomeOf;

/// The notes list: filters, reloads after pin/archive and on live events.
class NotesController extends ChangeNotifier {
  NotesController({required this.api, required this.live}) {
    _sub = live.events.listen((e) {
      if (e.isWorkspace && e.raw['module'] == 'notes') unawaited(load());
    });
  }

  final NotesApi api;
  final LiveService live;
  StreamSubscription<LiveEvent>? _sub;
  bool _disposed = false;
  List<NoteOut> _items = const [];
  NoteFilter _filter = const NoteFilter();
  bool _loading = true;
  Object? _error;

  List<NoteOut> get items => _items;
  NoteFilter get filter => _filter;
  bool get loading => _loading;
  Object? get error => _error;

  List<NoteOut> get pinned => [
    for (final n in _items)
      if (n.pinned) n,
  ];

  List<NoteOut> get others => [
    for (final n in _items)
      if (!n.pinned) n,
  ];

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> setFilter(NoteFilter filter) {
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

  Future<ActionOutcome> pin(NoteOut n, {required bool pinned}) =>
      _act(() => api.pin(n.id, pinned: pinned));

  Future<ActionOutcome> archive(NoteOut n, {required bool archived}) =>
      _act(() => api.archive(n.id, archived: archived));

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
