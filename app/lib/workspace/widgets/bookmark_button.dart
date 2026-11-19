import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/bookmarks/bookmarks_api.dart';
import 'package:letter_signing/bookmarks/models.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// App bar star that bookmarks one object (`PUT` / `DELETE /bookmarks`). It reads the module's
/// bookmarks once to know the initial state and hides itself when the server has no
/// bookmarks endpoint.
class BookmarkButton extends StatefulWidget {
  const BookmarkButton({
    super.key,
    required this.api,
    required this.module,
    required this.id,
  });

  final WorkspaceApi api;

  /// Server module code (`tasks`, `letters`, `meetings` ...).
  final String module;

  /// Subject id or module object id.
  final String id;

  @override
  State<BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<BookmarkButton> {
  late final BookmarksApi _api = BookmarksApi(widget.api);
  Bookmark? _bookmark;
  bool _ready = false;
  bool _busy = false;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final all = await _api.list(module: widget.module);
      _bookmark = all
          .where((b) => b.matches(widget.module, widget.id))
          .firstOrNull;
    } on NotFoundException {
      _unavailable = true;
    } on Object {
      // Offline: show the star, the first tap reports the failure.
    }
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _toggle() async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final current = _bookmark;
      if (current == null) {
        _bookmark = await _api.add(widget.module, widget.id);
      } else {
        await _api.remove(current.id);
        _bookmark = null;
      }
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l.bookmarkFailed)));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_unavailable) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final on = _bookmark != null;
    return IconButton(
      key: const ValueKey('bookmark-button'),
      tooltip: on ? l.bookmarkRemove : l.bookmarkAdd,
      icon: Icon(on ? Icons.bookmark : Icons.bookmark_border),
      onPressed: _ready && !_busy ? () => unawaited(_toggle()) : null,
    );
  }
}
