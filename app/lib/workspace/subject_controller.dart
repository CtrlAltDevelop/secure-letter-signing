import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/letters/models.dart' show LiveEvent;
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// Result of a user action against the server, for the screen to turn into a message.
enum ActionOutcome { ok, conflict, forbidden, notFound, failed }

/// Maps an exception to an [ActionOutcome].
ActionOutcome outcomeOf(Object error) => switch (error) {
  ConflictException() => ActionOutcome.conflict,
  ForbiddenException() => ActionOutcome.forbidden,
  NotFoundException() => ActionOutcome.notFound,
  _ => ActionOutcome.failed,
};

/// Comments, files, history and seen-by of one subject; each list loads on demand and
/// reloads on the matching live events (`comment.*`, `file.*`).
class SubjectController extends ChangeNotifier {
  SubjectController({
    required this.api,
    required this.live,
    required this.subjectId,
  }) {
    _sub = live.events.listen(_onLive);
  }

  final WorkspaceApi api;
  final LiveService live;
  final String subjectId;

  StreamSubscription<LiveEvent>? _sub;
  bool _disposed = false;
  List<CommentInfo>? _comments;
  List<FileInfo>? _files;
  List<HistoryEntry>? _history;
  List<SeenEntry>? _seen;
  Object? _lastError;

  /// Null until first loaded.
  List<CommentInfo>? get comments => _comments;
  List<FileInfo>? get files => _files;
  List<HistoryEntry>? get history => _history;
  List<SeenEntry>? get seen => _seen;

  /// The last failure, for [ActionOutcome.failed] messages.
  Object? get lastError => _lastError;

  void _onLive(LiveEvent e) {
    if (!e.isWorkspace || e.raw['subject_id'] != subjectId) return;
    if (e.kind.startsWith('comment.')) unawaited(loadComments());
    if (e.kind.startsWith('file.')) unawaited(loadFiles());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Runs a load and keeps the old list when it fails.
  Future<void> _load<T>(
    Future<List<T>> Function() fetch,
    void Function(List<T>) store,
  ) async {
    try {
      store(await fetch());
    } on Object catch (e) {
      _lastError = e;
    }
    _notify();
  }

  Future<void> loadComments() =>
      _load(() => api.comments(subjectId), (v) => _comments = v);
  Future<void> loadFiles() =>
      _load(() => api.files(subjectId), (v) => _files = v);
  Future<void> loadHistory() =>
      _load(() => api.history(subjectId), (v) => _history = v);
  Future<void> loadSeen() =>
      _load(() => api.seenBy(subjectId), (v) => _seen = v);

  /// Runs a write; on success [after] reloads what changed.
  Future<ActionOutcome> _act(
    Future<Object?> Function() action,
    Future<void> Function() after,
  ) async {
    try {
      await action();
    } on Object catch (e) {
      _lastError = e;
      return outcomeOf(e);
    }
    await after();
    return ActionOutcome.ok;
  }

  Future<ActionOutcome> postComment(
    String text, {
    int? parentId,
    String kind = CommentInfo.commentKind,
    int? progress,
  }) => _act(
    () => api.addComment(
      subjectId,
      text: text,
      parentId: parentId,
      kind: kind,
      progress: progress,
    ),
    loadComments,
  );

  Future<ActionOutcome> editComment(int id, String text) =>
      _act(() => api.editComment(id, text), loadComments);

  Future<ActionOutcome> deactivateComment(int id) =>
      _act(() => api.deactivateComment(id), loadComments);

  Future<ActionOutcome> uploadFile({
    required String name,
    required Uint8List bytes,
    required String contentType,
  }) => _act(
    () => api.uploadFile(
      subjectId,
      name: name,
      bytes: bytes,
      contentType: contentType,
    ),
    loadFiles,
  );

  Future<ActionOutcome> deactivateFile(String fileId) =>
      _act(() => api.deactivateFile(fileId), loadFiles);

  /// Bytes of a file, or null when the download failed (see [lastError]).
  Future<Uint8List?> download(FileInfo file) async {
    try {
      return await api.downloadFile(file.id);
    } on Object catch (e) {
      _lastError = e;
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
