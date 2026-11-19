import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/bookmarks/bookmarks_api.dart';
import 'package:letter_signing/bookmarks/models.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/module_label.dart';
import 'package:letter_signing/workspace/open_target.dart';

/// The "Pinned" section of the home screen: pinned projects, customers and conversations in
/// the order the user pinned them. A pin is opened by subject id (`kind: 'subject'`).
class PinnedScreen extends StatefulWidget {
  const PinnedScreen({super.key, required this.api, required this.open});

  final BookmarksApi api;
  final OpenFn open;

  @override
  State<PinnedScreen> createState() => _PinnedScreenState();
}

class _PinnedScreenState extends State<PinnedScreen> {
  List<Pin> _pins = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      _pins = await widget.api.pins();
      _error = null;
    } on Object catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _unpin(Pin p) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).pinFailed;
    try {
      await widget.api.unpin(p.subjectId);
      if (mounted) {
        setState(() => _pins = [..._pins.where((x) => x != p)]);
      }
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _pins.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: l.pinnedLoadFailed,
        action: OutlinedButton(
          onPressed: () {
            setState(() => _loading = true);
            unawaited(_load());
          },
          child: Text(l.commonRetry),
        ),
      );
    }
    if (_pins.isEmpty) {
      return EmptyState(
        icon: Icons.push_pin_outlined,
        title: l.pinnedEmpty,
        message: l.pinnedEmptyHint,
      );
    }
    return PageBody(
      child: ListView(
        children: [
          for (final p in _pins)
            ListTile(
              key: ValueKey('pin-${p.subjectId}'),
              leading: const Icon(Icons.push_pin),
              title: Text(p.title),
              subtitle: Text(moduleLabel(l, p.module)),
              trailing: IconButton(
                tooltip: l.pinRemove,
                icon: const Icon(Icons.close),
                onPressed: () => unawaited(_unpin(p)),
              ),
              onTap: () => unawaited(
                widget.open(
                  context,
                  OpenTarget(
                    module: p.module,
                    kind: p.objectId.isEmpty ? 'subject' : p.kind,
                    id: p.objectId.isEmpty ? p.subjectId : p.objectId,
                    subjectId: p.subjectId,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
