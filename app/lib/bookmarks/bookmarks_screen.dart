import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/bookmarks/bookmarks_api.dart';
import 'package:letter_signing/bookmarks/models.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/module_label.dart';
import 'package:letter_signing/workspace/open_target.dart';

/// `/bookmarks`: everything I starred (tasks, letters, meetings, chat messages ...), filtered
/// by module, newest first; tap opens the object, the trailing star removes it.
class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({
    super.key,
    required this.api,
    required this.open,
    this.embedded = false,
  });

  final BookmarksApi api;
  final OpenFn open;

  /// Inside the home shell: no app bar of its own.
  final bool embedded;

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<Bookmark> _all = const [];
  String? _module;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      _all = await widget.api.list();
      _error = null;
    } on Object catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _remove(Bookmark b) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).bookmarkFailed;
    try {
      await widget.api.remove(b.id);
      if (mounted) setState(() => _all = [..._all.where((x) => x.id != b.id)]);
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final body = _body(l);
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text(l.bookmarksTitle)),
      body: body,
    );
  }

  Widget _body(AppLocalizations l) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _all.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: l.bookmarksLoadFailed,
        action: OutlinedButton(
          onPressed: () {
            setState(() => _loading = true);
            unawaited(_load());
          },
          child: Text(l.commonRetry),
        ),
      );
    }
    final modules = {for (final b in _all) b.module};
    final shown = [
      for (final b in _all)
        if (_module == null || b.module == _module) b,
    ];
    if (_all.isEmpty) {
      return EmptyState(
        icon: Icons.bookmark_border,
        title: l.bookmarksEmpty,
        message: l.bookmarksEmptyHint,
      );
    }
    return PageBody(
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(l.tasksFilterAll),
                selected: _module == null,
                onSelected: (_) => setState(() => _module = null),
              ),
              for (final m in modules)
                ChoiceChip(
                  key: ValueKey('bm-filter-$m'),
                  label: Text(moduleLabel(l, m)),
                  selected: _module == m,
                  onSelected: (_) => setState(() => _module = m),
                ),
            ],
          ),
          Expanded(
            child: ListView(
              children: [for (final b in shown) _tile(context, b, l)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, Bookmark b, AppLocalizations l) =>
      ListTile(
        key: ValueKey('bm-${b.id}'),
        title: Text(b.title.isEmpty ? moduleLabel(l, b.module) : b.title),
        subtitle: Text(moduleLabel(l, b.module)),
        trailing: IconButton(
          tooltip: l.bookmarkRemove,
          icon: const Icon(Icons.bookmark),
          onPressed: () => unawaited(_remove(b)),
        ),
        onTap: () => unawaited(widget.open(context, b.target)),
      );
}
