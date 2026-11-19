import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';

/// Asks for a mandatory free-text reason (void a document, lose a lead). Pops the trimmed
/// text, or null when cancelled.
class ReasonDialog extends StatefulWidget {
  const ReasonDialog({
    super.key,
    required this.title,
    required this.label,
    required this.submit,
  });
  final String title;
  final String label;
  final String submit;

  @override
  State<ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<ReasonDialog> {
  final _reason = TextEditingController();
  bool _empty = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('reason-field'),
        controller: _reason,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: widget.label,
          errorText: _empty ? l.moneyVoidReasonRequired : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            final text = _reason.text.trim();
            if (text.isEmpty) {
              setState(() => _empty = true);
              return;
            }
            Navigator.pop(context, text);
          },
          child: Text(widget.submit),
        ),
      ],
    );
  }
}
