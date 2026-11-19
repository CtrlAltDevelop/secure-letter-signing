import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/bookmarks/bookmarks_api.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// App bar pin for a project, customer file or conversation (`PUT` / `DELETE /pins`).
class PinButton extends StatefulWidget {
  const PinButton({super.key, required this.api, required this.subjectId});

  final WorkspaceApi api;
  final String subjectId;

  @override
  State<PinButton> createState() => _PinButtonState();
}

class _PinButtonState extends State<PinButton> {
  late final BookmarksApi _api = BookmarksApi(widget.api);
  bool _pinned = false;
  bool _ready = false;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final pins = await _api.pins();
      _pinned = pins.any((p) => p.subjectId == widget.subjectId);
    } on NotFoundException {
      _unavailable = true;
    } on Object {
      // Offline: keep the button, the tap reports the failure.
    }
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _toggle() async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).pinFailed;
    try {
      if (_pinned) {
        await _api.unpin(widget.subjectId);
      } else {
        await _api.pin(widget.subjectId);
      }
      if (mounted) setState(() => _pinned = !_pinned);
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unavailable) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return IconButton(
      key: const ValueKey('pin-button'),
      tooltip: _pinned ? l.pinRemove : l.pinAdd,
      icon: Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined),
      onPressed: _ready ? () => unawaited(_toggle()) : null,
    );
  }
}
