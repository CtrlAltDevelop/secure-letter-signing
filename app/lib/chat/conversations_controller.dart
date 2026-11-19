import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:letter_signing/chat/chat_api.dart';
import 'package:letter_signing/chat/models.dart';
import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/letters/models.dart' show LiveEvent;
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/subject_controller.dart'
    show ActionOutcome, outcomeOf;

/// The conversation list: mine (pinned first, then latest activity) or the public ones to
/// join. Message and read frames patch unread counts in place; anything else reloads.
class ConversationsController extends ChangeNotifier {
  ConversationsController({
    required this.api,
    required this.live,
    required this.userId,
  }) {
    _sub = live.events.listen(_onLive);
  }

  final ChatApi api;
  final LiveService live;
  final int userId;
  StreamSubscription<LiveEvent>? _sub;
  bool _disposed = false;
  List<Conversation> _items = const [];
  ConvFilter _filter = const ConvFilter();
  bool _loading = true;
  Object? _error;

  List<Conversation> get items => _items;
  ConvFilter get filter => _filter;
  bool get loading => _loading;
  Object? get error => _error;

  /// Unread messages of the conversations that are not muted.
  int get totalUnread => [
    for (final c in _items)
      if (!c.muted) c.unread,
  ].fold(0, (a, b) => a + b);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> setFilter(ConvFilter filter) {
    _filter = filter;
    _loading = true;
    _notify();
    return load();
  }

  Future<void> load() async {
    try {
      _items = _sorted(await api.conversations(_filter));
      _error = null;
    } on Object catch (e) {
      _error = e;
    }
    _loading = false;
    _notify();
  }

  static List<Conversation> _sorted(List<Conversation> rows) {
    final out = [...rows];
    out.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final x = a.lastMessageAt;
      final y = b.lastMessageAt;
      if (x == null || y == null) return x == null ? (y == null ? 0 : 1) : -1;
      return y.compareTo(x);
    });
    return out;
  }

  void _onLive(LiveEvent e) {
    if (!e.isWorkspace || e.raw['module'] != 'chat' || _filter.publicOnly) {
      return;
    }
    final data = asMap(e.raw['data']);
    final i = _items.indexWhere((c) => c.id == data['conversation_id']);
    final kind = e.raw['kind'];
    if (kind == 'chat.message' && i >= 0) {
      _patchMessage(i, data);
    } else if (kind == 'chat.read' && i >= 0 && data['user_id'] == userId) {
      final c = _items[i];
      final seq = asInt(data['seq']) ?? 0;
      _replace(
        i,
        c.copyWith(
          lastReadSeq: seq,
          unread: (c.lastSeq - seq).clamp(0, c.unread),
          mentionUnread: seq >= c.lastSeq ? 0 : c.mentionUnread,
        ),
      );
    } else if (i < 0 ||
        kind == 'chat.message_deleted' ||
        kind == 'chat.member_added') {
      unawaited(load());
    }
  }

  void _patchMessage(int i, Map<String, dynamic> data) {
    final c = _items[i];
    final seq = asInt(data['seq']) ?? c.lastSeq + 1;
    if (seq <= c.lastSeq) return;
    final mine = data['author_id'] == userId;
    final preview = data['preview'];
    _replace(
      i,
      c.copyWith(
        lastSeq: seq,
        unread: mine ? c.unread : c.unread + 1,
        lastPreview: preview is String ? preview : null,
        lastMessageAt: DateTime.now(),
      ),
    );
  }

  void _replace(int i, Conversation c) {
    _items = _sorted([..._items]..[i] = c);
    _notify();
  }

  /// Marks a conversation as read locally (the open screen posts the read itself).
  void markReadLocally(String id) {
    final i = _items.indexWhere((c) => c.id == id);
    if (i < 0) return;
    final c = _items[i];
    _replace(
      i,
      c.copyWith(unread: 0, mentionUnread: 0, lastReadSeq: c.lastSeq),
    );
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

  Future<ActionOutcome> pin(Conversation c, {required bool pinned}) =>
      _act(() => api.pinConversation(c.id, pinned: pinned));

  Future<ActionOutcome> mute(Conversation c, {required bool muted}) =>
      _act(() => api.mute(c.id, muted: muted));

  Future<ActionOutcome> join(Conversation c) => _act(() => api.join(c.id));

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
