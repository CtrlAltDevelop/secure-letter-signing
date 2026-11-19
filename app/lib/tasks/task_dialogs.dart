import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';

/// Asks for a note. Resolves to the text (possibly empty when not [required]) or null when
/// cancelled. A required note disables the confirm button while empty.
Future<String?> showNoteDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? hint,
  bool required = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => _NoteDialog(
    title: title,
    confirmLabel: confirmLabel,
    hint: hint,
    required: required,
  ),
);

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({
    required this.title,
    required this.confirmLabel,
    required this.required,
    this.hint,
  });

  final String title;
  final String confirmLabel;
  final String? hint;
  final bool required;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = _controller.text.trim();
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 2,
        maxLines: 5,
        maxLength: 2000,
        decoration: InputDecoration(hintText: widget.hint),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: widget.required && text.isEmpty
              ? null
              : () => Navigator.pop(context, _controller.text.trim()),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// A yes/no confirmation; resolves to true only on confirm.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final l = AppLocalizations.of(context);
  final yes = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return yes ?? false;
}
