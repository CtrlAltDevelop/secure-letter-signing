import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:letter_signing/chat/chat_api.dart';
import 'package:letter_signing/chat/models.dart';
import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/letters/models.dart' show LiveEvent;
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/subject_controller.dart'
    show ActionOutcome, outcomeOf;

const _pageSize = 50;

/// One open conversation: messages by `seq` (latest page first, older pages on demand, or a
/// window starting at a chosen day), sending, deleting, pins, read marking and live frames.
class ConversationController extends ChangeNotifier {
  ConversationController({
    required this.api,
    required this.live,
    required this.userId,
    required this.conversationId,
    this.initial,
  }) {
    _conv = initial;
    _sub = live.events.listen(_onLive);
  }

  final ChatApi api;
  final LiveService live;
  final int userId;
  final String conversationId;
  final Conversation? initial;

  StreamSubscription<LiveEvent>? _sub;
  bool _disposed = false;
  Conversation? _conv;
  List<ChatMessage> _messages = const [];
  List<ChatMessage> _pins = const [];
  bool _loading = true;
  bool _hasOlder = false;
  bool _atLatest = true;
  bool _busy = false;
  Object? _error;
  ChatMessage? _replyTo;
  int _readSent = 0;
  int _windowJumps = 0;
  final Map<int, int> _readSeqByUser = {};

  Conversation? get conversation => _conv;

  /// Ascending by `seq`.
  List<ChatMessage> get messages => _messages;
  List<ChatMessage> get pins => _pins;
  bool get loading => _loading;
  bool get hasOlder => _hasOlder;

  /// False after a jump to a date: newer messages load when scrolling down.
  bool get atLatest => _atLatest;
  Object? get error => _error;

  /// Bumped when the shown window was replaced by a jump; the view scrolls to its oldest end.
  int get windowJumps => _windowJumps;
  ChatMessage? get replyTo => _replyTo;

  /// Highest `seq` [userId] has read, as far as live `chat.read` frames told us.
  int readSeqOf(int userId) => _readSeqByUser[userId] ?? 0;

  bool get canPost => (_conv?.isMember ?? false) && (_conv?.canPost ?? false);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setReplyTo(ChatMessage? m) {
    _replyTo = m;
    _notify();
  }

  Future<void> load() async {
    _loading = true;
    _notify();
    try {
      _conv = await api.conversation(conversationId);
      if (_conv!.isMember) {
        _setWindow(await api.messages(conversationId), latest: true);
        unawaited(_loadPins());
        unawaited(markRead());
      } else {
        _messages = const [];
      }
      _error = null;
    } on Object catch (e) {
      _error = e;
    }
    _loading = false;
    _notify();
  }

  void _setWindow(List<ChatMessage> rows, {required bool latest}) {
    _messages = rows;
    _atLatest = latest;
    _hasOlder = rows.isNotEmpty && rows.first.seq > 1;
  }

  List<ChatMessage> _merge(Iterable<ChatMessage> extra) {
    final byId = {
      for (final m in _messages) m.id: m,
      for (final m in extra) m.id: m,
    };
    return byId.values.toList()..sort((a, b) => a.seq.compareTo(b.seq));
  }

  Future<void> _loadPins() async {
    try {
      _pins = await api.pins(conversationId);
      _notify();
    } on Object {
      // The bar is optional; keep the old list.
    }
  }

  Future<void> loadOlder() async {
    if (_busy || !_hasOlder || _messages.isEmpty) return;
    _busy = true;
    try {
      final rows = await api.messages(
        conversationId,
        beforeSeq: _messages.first.seq,
      );
      _messages = _merge(rows);
      _hasOlder = rows.length >= _pageSize && _messages.first.seq > 1;
      if (rows.isEmpty) _hasOlder = false;
    } on Object catch (e) {
      _error = e;
    }
    _busy = false;
    _notify();
  }

  Future<void> loadNewer() async {
    if (_busy || _atLatest || _messages.isEmpty) return;
    _busy = true;
    try {
      final rows = await api.messages(
        conversationId,
        afterSeq: _messages.last.seq,
      );
      _messages = _merge(rows);
      if (rows.length < _pageSize) _atLatest = true;
    } on Object catch (e) {
      _error = e;
    }
    _busy = false;
    _notify();
  }

  /// Shows the window starting at the first message on or after [day]; false when none.
  Future<bool> jumpToDate(DateTime day) async {
    final iso =
        '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    try {
      final rows = await api.messages(conversationId, aroundDate: iso);
      if (rows.isEmpty) return false;
      _setWindow(rows, latest: rows.length < _pageSize);
      _windowJumps++;
      _notify();
      return true;
    } on Object catch (e) {
      _error = e;
      _notify();
      return false;
    }
  }

  /// Shows the window starting at message [seq] (a pin or a quoted reply).
  Future<void> jumpToSeq(int seq) async {
    if (_messages.any((m) => m.seq == seq)) return;
    try {
      final rows = await api.messages(conversationId, afterSeq: seq - 1);
      if (rows.isEmpty) return;
      _setWindow(rows, latest: rows.length < _pageSize);
      _windowJumps++;
    } on Object catch (e) {
      _error = e;
    }
    _notify();
  }

  Future<void> jumpToLatest() async {
    try {
      _setWindow(await api.messages(conversationId), latest: true);
      unawaited(markRead());
    } on Object catch (e) {
      _error = e;
    }
    _notify();
  }

  Future<void> markRead() async {
    final seq = _messages.isEmpty ? 0 : _messages.last.seq;
    if (!_atLatest || seq <= _readSent || seq <= (_conv?.lastReadSeq ?? 0)) {
      return;
    }
    _readSent = seq;
    try {
      await api.markRead(conversationId, seq);
    } on Object {
      _readSent = 0;
    }
  }

  void _onLive(LiveEvent e) {
    if (!e.isWorkspace || e.raw['module'] != 'chat') return;
    final data = asMap(e.raw['data']);
    if (data['conversation_id'] != conversationId) return;
    final seq = asInt(data['seq']) ?? 0;
    switch (e.raw['kind']) {
      case 'chat.message':
        if (_atLatest && !_messages.any((m) => m.seq == seq)) {
          unawaited(_fetchNew());
        }
      case 'chat.message_edited' || 'chat.message_deleted':
        unawaited(_refetch(seq));
      case 'chat.pinned':
        final id = asInt(data['message_id']);
        _messages = [
          for (final m in _messages)
            m.id == id ? m.copyWith(pinned: data['pinned'] == true) : m,
        ];
        unawaited(_loadPins());
        _notify();
      case 'chat.read':
        final who = asInt(data['user_id']) ?? 0;
        if (who != userId && seq > readSeqOf(who)) {
          _readSeqByUser[who] = seq;
          _notify();
        }
    }
  }

  Future<void> _fetchNew() async {
    try {
      final after = _messages.isEmpty ? 0 : _messages.last.seq;
      _messages = _merge(await api.messages(conversationId, afterSeq: after));
      _notify();
      unawaited(markRead());
    } on Object {
      // The next frame or a refresh catches up.
    }
  }

  Future<void> _refetch(int seq) async {
    if (!_messages.any((m) => m.seq == seq)) return;
    try {
      final rows = await api.messages(
        conversationId,
        afterSeq: seq - 1,
        limit: 1,
      );
      _messages = _merge(rows);
      _notify();
      unawaited(_loadPins());
    } on Object {
      // Keep the old copy.
    }
  }

  Future<ActionOutcome> _act(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (e) {
      _error = e;
      _notify();
      return outcomeOf(e);
    }
    return ActionOutcome.ok;
  }

  /// Posts a message (optionally with an already uploaded [fileId]) and shows it at once.
  Future<ActionOutcome> send({
    String text = '',
    List<int> mentions = const [],
    String? fileId,
    String? kind,
  }) async {
    final reply = _replyTo;
    final out = await _act(() async {
      final m = await api.send(
        conversationId,
        text: text,
        replyToId: reply?.id,
        mentions: mentions,
        fileId: fileId,
        kind: kind,
      );
      if (_atLatest) _messages = _merge([m]);
      _replyTo = null;
      _readSent = _messages.last.seq;
      _notify();
    });
    return out;
  }

  /// Uploads [bytes] to the conversation subject, then posts them as a file (or voice) message.
  Future<ActionOutcome> sendFile({
    required String name,
    required Uint8List bytes,
    required String contentType,
    String text = '',
    String? kind,
  }) async {
    final c = _conv;
    if (c == null) return ActionOutcome.failed;
    String? fileId;
    final up = await _act(() async {
      fileId = (await api.uploadFile(
        c,
        name: name,
        bytes: bytes,
        contentType: contentType,
      )).id;
    });
    if (up != ActionOutcome.ok) return up;
    return send(text: text, fileId: fileId, kind: kind);
  }

  Future<ActionOutcome> delete(ChatMessage m) => _act(() async {
    final t = await api.delete(m.id);
    _messages = _merge([t]);
    _pins = [
      for (final p in _pins)
        if (p.id != m.id) p,
    ];
    _notify();
  });

  Future<ActionOutcome> setMessagePinned(
    ChatMessage m, {
    required bool pinned,
  }) => _act(() async {
    await api.pinMessage(m.id, pinned: pinned);
    _messages = [
      for (final x in _messages) x.id == m.id ? x.copyWith(pinned: pinned) : x,
    ];
    await _loadPins();
  });

  Future<ActionOutcome> bookmark(ChatMessage m) =>
      _act(() => api.bookmark(m.id));

  Future<ActionOutcome> join() => _act(() async {
    _conv = await api.join(conversationId);
    await load();
  });

  Future<ChatSeenResult?> seen(ChatMessage m) async {
    try {
      return await api.seen(m.id);
    } on Object {
      return null;
    }
  }

  /// Refreshes the conversation row (members, name) after an edit elsewhere.
  Future<void> reloadConversation() async {
    try {
      _conv = await api.conversation(conversationId);
      _notify();
    } on Object {
      // Keep the old one.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
